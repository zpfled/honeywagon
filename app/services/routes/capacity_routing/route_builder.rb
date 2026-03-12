module Routes
  module CapacityRouting
    # Builds one or more routes for a cluster using greedy ordering + capacity checks.
    class RouteBuilder
      RoutePlan = Struct.new(:date, :stops, :warnings, :errors, keyword_init: true)

      def initialize(company:, start_date:, candidates:)
        @company = company
        @start_date = start_date
        @candidates = Array(candidates)
        @distance_lookup = DistanceLookup.new(company: company)
      end

      def routes
        remaining = candidates.dup
        routes = []

        while remaining.any?
          route = build_single_route(remaining)
          routes << route
          # Known edge case for follow-up: strict home-base termination may
          # produce routes with only operational stops.
        end

        routes
      end

      private

      attr_reader :company, :start_date, :candidates, :distance_lookup

      def build_single_route(remaining)
        stops = []
        warnings = []
        errors = []
        route_state = RouteState.new(
          waste_gal: starting_waste_load,
          clean_water_gal: clean_capacity.to_f,
          current_position: home_base,
          trailer_inventory: {}
        )
        config = TruckConfig.new(truck: preferred_truck, trailer: preferred_trailer, company: company)

        last_location = route_state.current_position
        current_date = start_date
        placed_event = false
        iterations = 0
        max_iterations = [ remaining.size * 3, 1000 ].max

        loop do
          iterations += 1
          if iterations > max_iterations
            raise "CapacityRouting::RouteBuilder exceeded #{max_iterations} iterations; remaining=#{remaining.size} stops=#{stops.size}"
          end

          eligible = eligible_candidates(remaining, current_date)
          candidate = next_candidate(eligible, last_location, current_date)
          unless candidate
            next_date = remaining.map { |item| item.event&.scheduled_on }.compact.min
            break unless next_date

            current_date = next_date
            next
          end

          event = candidate.event

          inserter_result = OperationalStopInserter.new(
            route_state,
            event,
            config,
            remaining_stops: remaining.reject { |item| item == candidate }.map(&:event),
            distance_lookup: distance_lookup
          ).call
          warnings.concat(Array(inserter_result.warnings))
          errors.concat(Array(inserter_result.errors))

          if inserter_result.errors.present?
            remaining.delete(candidate)
            next
          end

          if inserter_result.resequence
            move_candidate_before_current!(remaining, candidate: candidate, stop_id: inserter_result.resequence[:stop_id])
            next
          end

          inserter_result.operational_stops.compact.each do |stop|
            stops << stop
            route_state.apply_stop!(stop, config)
            last_location = route_state.current_position || last_location
          end

          if inserter_result.terminate_route
            # Strict spec behavior: any home-base visit ends this route.
            break
          end

          stops << event
          remaining.delete(candidate)
          placed_event = true
          route_state.apply_stop!(event, config)
          last_location = route_state.current_position || last_location
          current_date = update_current_date(current_date, event)
        end

        if !placed_event && remaining.any?
          # Fallback to guarantee forward progress if every candidate is blocked by capacity rules.
          blocked = remaining.shift
          stops << blocked.event
        end

        RoutePlan.new(date: current_date, stops: reorder_for_dump(stops), warnings: warnings.uniq, errors: errors)
      end

      def next_candidate(remaining, last_location, current_date)
        remaining.min_by do |candidate|
          score_for(candidate, last_location, current_date)
        end
      end

      def reorder_for_dump(stops)
        dump_index = stops.index { |stop| stop.is_a?(Hash) && stop[:type] == :dump }
        return stops unless dump_index

        dump_location = stops[dump_index][:location]
        return stops unless dump_location

        prefix = stops.first(dump_index)
        reorderable = prefix.each_with_index.select { |stop, _| stop.is_a?(ServiceEvent) }
        return stops if reorderable.size <= 1

        sorted_events = reorderable.sort_by do |stop, index|
          distance = distance_lookup.distance_km(from: stop.order&.location, to: dump_location) || Float::INFINITY
          [ -distance, index ]
        end.map(&:first)

        reordered_prefix = prefix.dup
        reorderable.map(&:last).zip(sorted_events).each do |idx, stop|
          reordered_prefix[idx] = stop
        end

        reordered_prefix + stops.drop(dump_index)
      end

      def eligible_candidates(remaining, current_date)
        remaining.select do |candidate|
          event = candidate.event
          next false unless event&.scheduled_on

          if event.event_type_pickup?
            event.scheduled_on == current_date
          elsif event.event_type_delivery?
            event.scheduled_on >= current_date
          else
            event.scheduled_on >= current_date - company.routing_horizon_days.days
          end
        end
      end

      def score_for(candidate, last_location, current_date)
        distance_score = distance_lookup.distance_km(from: last_location, to: candidate.location) || 0
        urgency_score = days_until_due(candidate, current_date)
        remote_score = distance_from_home(candidate).to_f / 100.0

        # Lower scores are chosen first; urgency and distance dominate.
        distance_score + urgency_score + remote_score
      end

      def days_until_due(candidate, current_date)
        return 0 unless candidate.due_date
        (candidate.due_date - current_date).to_i.abs
      end

      def distance_from_home(candidate)
        distance_lookup.distance_km(from: home_base, to: candidate.location)
      end

      def event_usage(event)
        @event_usage ||= {}
        @event_usage[event.id] ||= ServiceEvents::ResourceCalculator.new(event).usage
      end

      def clean_capacity
        preferred_truck&.clean_water_capacity_gal
      end

      def starting_waste_load
        preferred_truck&.waste_load_gal.to_i
      end

      def preferred_trailer
        @preferred_trailer ||= begin
          trailers = company.trailers
          return if trailers.blank?

          required_spots = required_trailer_spots
          eligible = trailers.where('capacity_spots >= ?', required_spots)
          scope = eligible.presence || trailers
          scope.order(:capacity_spots, Arel.sql('preference_rank IS NULL'), :preference_rank).first
        end
      end

      def preferred_truck
        @preferred_truck ||= begin
          trucks = company.trucks
          return if trucks.blank?

          trucks.order(Arel.sql('preference_rank IS NULL'), :preference_rank, :waste_capacity_gal).first
        end
      end

      def required_trailer_spots
        return 0 if candidates.blank?

        candidates.map { |candidate| event_usage(candidate.event)[:trailer_spots].to_i }.max.to_i
      end

      def home_base
        company.home_base
      end

      def update_current_date(current_date, event)
        if event.event_type_delivery? && event.scheduled_on < current_date
          event.scheduled_on
        elsif event.event_type_pickup? && event.scheduled_on
          event.scheduled_on
        else
          current_date
        end
      end

      def move_candidate_before_current!(remaining, candidate:, stop_id:)
        index = remaining.index { |item| item.event.id == stop_id }
        return unless index

        target = remaining.delete_at(index)
        current_index = remaining.index(candidate) || 0
        remaining.insert(current_index, target)
      end
    end
  end
end
