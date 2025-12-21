module Routes
  module Optimization
    # Walks through a sequence of events and tracks resource usage, flagging
    # when a truck/trailer would exceed its limits. Later we can insert dump
    # stops automatically, but for now we just report violations so the UX
    # can surface them.
    class CapacitySimulator
      Step = Struct.new(:event_id, :waste_used, :clean_used, :trailer_used, keyword_init: true)
      Result = Struct.new(:steps, :violations, keyword_init: true)

      def initialize(route:, ordered_event_ids:)
        @route = route
        @ordered_events = load_events_in_order(ordered_event_ids)
      end

      def self.call(route:, ordered_event_ids:)
        new(route: route, ordered_event_ids: ordered_event_ids).call
      end

      def call
        steps = []
        violations = []

        ordered_events.each do |event|
          usage = ServiceEvents::ResourceCalculator.new(event).usage

          apply_usage(usage, event)
          reset_for_dump! if event.event_type_dump?

          steps << Step.new(
            event_id: event.id,
            waste_used: waste_used,
            clean_used: clean_water_used,
            trailer_used: trailer_used
          )

          violations.concat(violations_for(event))
        end

        Result.new(steps: steps, violations: violations)
      end

      private

      attr_reader :route, :ordered_events

      def load_events_in_order(ids)
        @events_by_id = route.service_events.where(id: ids).includes(order: :customer, dump_site: :location).index_by(&:id)
        ids.map { |id| @events_by_id[id] }.compact
      end

      def waste_used
        @waste_used ||= 0
      end

      def clean_water_used
        @clean_water_used ||= 0
      end

      def trailer_used
        @trailer_used ||= 0
      end

      def waste_capacity
        route.truck&.waste_capacity_gal
      end

      def clean_capacity
        route.truck&.clean_water_capacity_gal
      end

      def trailer_capacity
        route.trailer&.capacity_spots
      end

      def apply_usage(usage, event)
        waste_delta = usage[:waste_gallons].to_i
        clean_delta = usage[:clean_water_gallons].to_i
        trailer_delta = usage[:trailer_spots].to_i

        @waste_used = if event.event_type_dump?
                        waste_delta
        else
                        waste_used + waste_delta
        end
        @clean_water_used = clean_water_used + clean_delta
        @trailer_used = trailer_used + trailer_delta

        track_last_safe_stop(event)
      end

      def reset_for_dump!
        @waste_used = 0
      end

      def violations_for(event)
        [].tap do |list|
          if waste_capacity && waste_used > waste_capacity
            list << waste_violation_message(event)
          end

          if clean_capacity && clean_water_used > clean_capacity
            list << violation_message(event, :clean_water, clean_water_used, clean_capacity)
          end

          if trailer_capacity && trailer_used > trailer_capacity
            list << violation_message(event, :trailer, trailer_used, trailer_capacity)
          end
        end
      end

      def waste_violation_message(event)
        message = violation_message(event, :waste, waste_used, waste_capacity)
        if @last_safe_event && @last_safe_event != event
          message += " Consider adding a dump stop after #{event_label(@last_safe_event)}."
        end
        message
      end

      def violation_message(event, resource, used, capacity)
        "#{resource.to_s.humanize} capacity exceeded after #{event.event_type} (#{used} / #{capacity})."
      end

      def track_last_safe_stop(event)
        return unless waste_capacity
        if waste_used <= waste_capacity
          @last_safe_event = event
        end
      end

      def event_label(event)
        if event.event_type_dump?
          event.dump_site&.name || 'dump event'
        else
          event.order&.customer&.display_name || 'service event'
        end
      end
    end
  end
end
