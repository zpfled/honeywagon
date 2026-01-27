module Routes
  module CapacityRouting
    # Builds one or more routes for a cluster using greedy ordering + capacity checks.
    class RouteBuilder
      RoutePlan = Struct.new(:date, :stops, keyword_init: true)

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
        end

        routes
      end

      private

      attr_reader :company, :start_date, :candidates, :distance_lookup

      def build_single_route(remaining)
        stops = []
        delivered_spots = 0
        picked_up_spots = 0
        total_delivery_spots = 0
        waste_used = starting_waste_load
        clean_used = 0
        last_location = home_base
        current_date = start_date
        placed_event = false
        iterations = 0
        max_iterations = [ remaining.size * 3, 1000 ].max

        loop do
          iterations += 1
          if iterations > max_iterations
            raise "CapacityRouting::RouteBuilder exceeded #{max_iterations} iterations; remaining=#{remaining.size} stops=#{stops.size}"
          end
          if dump_threshold && waste_used >= dump_threshold && stops.empty?
            dump_site = nearest_dump_site(last_location)
            if dump_site
              stops << virtual_dump_stop(dump_site)
              waste_used = 0
              last_location = dump_site.location || last_location
            end
          end

          eligible = eligible_candidates(remaining, current_date)
          candidate = next_candidate(
            eligible,
            last_location,
            current_date,
            waste_used: waste_used,
            clean_used: clean_used,
            total_delivery_spots: total_delivery_spots,
            delivered_spots: delivered_spots,
            picked_up_spots: picked_up_spots
          )
          unless candidate
            next_date = remaining.map { |item| item.event&.scheduled_on }.compact.min
            break unless next_date

            current_date = next_date
            next
          end

          event = candidate.event
          usage = event_usage(event)
          waste_delta = usage[:waste_gallons].to_i
          clean_delta = usage[:clean_water_gallons].to_i
          delivery_delta = delivery_spots(event)

          inserted_dump = false
          if dump_needed_before?(waste_used, waste_delta)
            dump_site = nearest_dump_site(last_location)
            if dump_site
              stops << virtual_dump_stop(dump_site)
              waste_used = 0
              last_location = dump_site.location || last_location
              inserted_dump = true
            end
          end

          if clean_capacity && clean_used + clean_delta > clean_capacity
            if home_base && placed_event
              stops << virtual_home_stop(:refill, reset_clean: true)
              break
            end
          end

          pickup_delta = pickup_spots(event)
          if trailer_capacity && delivery_delta.positive?
            projected_deliveries = total_delivery_spots + delivery_delta
            if projected_deliveries > trailer_capacity
              if placed_event
                stops << virtual_home_stop(:reload, reset_trailer: true)
                break
              end
            end
          end
          if trailer_capacity && pickup_delta.positive?
            current_used = trailer_used(total_delivery_spots, delivered_spots, picked_up_spots)
            if current_used + pickup_delta > trailer_capacity
              if placed_event
                stops << virtual_home_stop(:reload, reset_trailer: true)
                break
              end
            end
          end

          total_delivery_spots += delivery_delta

          projected_used = trailer_used(total_delivery_spots, delivered_spots, picked_up_spots)
          if trailer_capacity && projected_used > trailer_capacity
            if stops.any?
              # End the route at home base when trailer capacity would be exceeded.
              stops << virtual_home_stop(:reload, reset_trailer: true)
              break
            else
              # Ensure forward progress even if the first stop exceeds trailer capacity.
              stops << event
              remaining.delete(candidate)
              placed_event = true
              delivered_spots += delivery_spots(event)
              picked_up_spots += pickup_spots(event)
              last_location = candidate.location || last_location
              current_date = event.scheduled_on if event.event_type_delivery? && event.scheduled_on < current_date
              waste_used += waste_delta
              clean_used += clean_delta
              next
            end
          end

          stops << event
          remaining.delete(candidate)
          placed_event = true

          delivered_spots += delivery_spots(event)
          picked_up_spots += pickup_delta
          last_location = candidate.location || last_location
          waste_used += waste_delta
          clean_used += clean_delta

          if dump_threshold && waste_used >= dump_threshold && !inserted_dump
            dump_site = nearest_dump_site(last_location)
            if dump_site
              stops << virtual_dump_stop(dump_site)
              waste_used = 0
              last_location = dump_site.location || last_location
            end
          end

          if event.event_type_delivery? && event.scheduled_on < current_date
            current_date = event.scheduled_on
          elsif event.event_type_pickup?
            current_date = event.scheduled_on if event.scheduled_on
          end
        end

        if !placed_event && remaining.any?
          # Fallback to guarantee forward progress if every candidate is blocked by capacity rules.
          blocked = remaining.shift
          stops << blocked.event
        end

        RoutePlan.new(date: current_date, stops: reorder_for_dump(stops))
      end

      def next_candidate(remaining, last_location, current_date, waste_used:, clean_used:, total_delivery_spots:, delivered_spots:, picked_up_spots:)
        remaining.min_by do |candidate|
          score_for(
            candidate,
            last_location,
            current_date,
            waste_used: waste_used,
            clean_used: clean_used,
            total_delivery_spots: total_delivery_spots,
            delivered_spots: delivered_spots,
            picked_up_spots: picked_up_spots
          )
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

      def score_for(candidate, last_location, current_date, waste_used:, clean_used:, total_delivery_spots:, delivered_spots:, picked_up_spots:)
        distance_score = distance_lookup.distance_km(from: last_location, to: candidate.location) || 0
        urgency_score = days_until_due(candidate, current_date)
        remote_score = distance_from_home(candidate).to_f / 100.0
        # Bias toward dump/home when capacity is getting tight to keep the last stop nearby.
        dump_bias = dump_bias_score(candidate, waste_used)
        home_bias = home_bias_score(candidate, total_delivery_spots, delivered_spots, picked_up_spots)

        # Lower scores are chosen first; urgency and distance dominate.
        distance_score + urgency_score + remote_score + dump_bias + home_bias
      end

      def days_until_due(candidate, current_date)
        return 0 unless candidate.due_date
        (candidate.due_date - current_date).to_i.abs
      end

      def distance_from_home(candidate)
        distance_lookup.distance_km(from: home_base, to: candidate.location)
      end

      def delivery_spots(event)
        return 0 unless event.event_type_delivery?
        event_usage(event)[:trailer_spots].to_i
      end

      def pickup_spots(event)
        return 0 unless event.event_type_pickup?
        event_usage(event)[:trailer_spots].to_i
      end

      def event_usage(event)
        @event_usage ||= {}
        @event_usage[event.id] ||= ServiceEvents::ResourceCalculator.new(event).usage
      end

      def trailer_used(total_delivery_spots, delivered_spots, picked_up_spots)
        [ total_delivery_spots - delivered_spots + picked_up_spots, 0 ].max
      end

      def trailer_capacity
        preferred_trailer&.capacity_spots
      end

      def waste_capacity
        preferred_truck&.waste_capacity_gal
      end

      def clean_capacity
        preferred_truck&.clean_water_capacity_gal
      end

      def dump_threshold_percent
        company.dump_threshold_percent || 90
      end

      def dump_threshold
        return unless waste_capacity

        waste_capacity * (dump_threshold_percent.to_f / 100.0)
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

      def dump_sites_with_locations
        @dump_sites_with_locations ||= company.dump_sites.includes(:location).to_a
      end

      def home_base
        company.home_base
      end

      def dump_needed_before?(waste_used, waste_delta)
        return false unless dump_threshold

        waste_used + waste_delta > dump_threshold
      end

      def nearest_dump_site(from_location)
        return unless from_location

        @nearest_dump_sites ||= {}
        return @nearest_dump_sites[from_location.id] if @nearest_dump_sites.key?(from_location.id)

        @nearest_dump_sites[from_location.id] = dump_sites_with_locations.min_by do |site|
          distance_lookup.distance_km(from: from_location, to: site.location) || Float::INFINITY
        end
      end

      def dump_bias_score(candidate, waste_used)
        return 0 unless waste_capacity
        return 0 unless waste_used.positive?

        remaining_ratio = (waste_capacity - waste_used).to_f / waste_capacity
        return 0 unless remaining_ratio <= 0.2

        dump_site = nearest_dump_site(candidate.location)
        return 0 unless dump_site

        distance_lookup.distance_km(from: candidate.location, to: dump_site.location).to_f * 0.25
      end

      def home_bias_score(candidate, total_delivery_spots, delivered_spots, picked_up_spots)
        return 0 unless trailer_capacity
        return 0 unless home_base

        projected_used = trailer_used(
          total_delivery_spots + delivery_spots(candidate.event),
          delivered_spots,
          picked_up_spots
        )
        remaining_ratio = (trailer_capacity - projected_used).to_f / trailer_capacity
        return 0 unless remaining_ratio <= 0.2

        distance_lookup.distance_km(from: candidate.location, to: home_base).to_f * 0.25
      end

      def virtual_dump_stop(dump_site)
        { type: :dump, location: dump_site.location, dump_site: dump_site }
      end

      def virtual_home_stop(reason, reset_clean: false, reset_trailer: false)
        { type: :home_base, location: home_base, reason: reason, reset_clean: reset_clean, reset_trailer: reset_trailer }
      end
    end
  end
end
