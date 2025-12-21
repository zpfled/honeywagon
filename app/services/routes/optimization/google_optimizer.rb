module Routes
  module Optimization
    # Placeholder optimizer that will eventually delegate to Google Routes.
    # For now it validates that every stop has coordinates and returns the
    # current event order so we can build the pipeline step-by-step.
    class GoogleOptimizer
      Result = Struct.new(:event_ids_in_order, :warnings, :errors, :simulation, keyword_init: true)

      def initialize(route)
        @route = route
      end

      def self.call(route)
        new(route).call
      end

      def call
        errors = missing_coordinate_events.map do |event|
          "#{event_label(event)} is missing latitude/longitude"
        end

        return failure_result(errors) if errors.any?

        event_ids = ordered_events.map(&:id)
        simulation = Routes::Optimization::CapacitySimulator.call(route: route, ordered_event_ids: event_ids)

        Result.new(
          event_ids_in_order: event_ids,
          warnings: base_warnings(simulation),
          errors: [],
          simulation: simulation
        )
      end

      private

      attr_reader :route

      def ordered_events
          @ordered_events ||= route.service_events.order(:route_date, :event_type, :created_at)
      end

      def missing_coordinate_events
        ordered_events.reject { |event| stop_coordinate_present?(event) }
      end

      def stop_coordinate_present?(event)
        if event.event_type_dump?
          event.dump_site&.location&.lat.present? && event.dump_site&.location&.lng.present?
        else
          location = event.order&.location
          location&.lat.present? && location&.lng.present?
        end
      end

      def event_label(event)
        if event.event_type_dump?
          "Dump event #{event.id}"
        else
          customer_name = event.order&.customer&.display_name || 'Unknown customer'
          "#{event.event_type.titleize} for #{customer_name}"
        end
      end
      def failure_result(errors)
        Result.new(event_ids_in_order: [], warnings: [], errors: errors, simulation: nil)
      end

      def base_warnings(simulation)
        warnings = []
        warnings << 'Using existing ordering until Google optimizer is wired up.'
        if simulation.violations.any?
          warnings.concat(simulation.violations)
        end
        warnings
      end
    end
  end
end
