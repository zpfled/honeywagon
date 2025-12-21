module Routes
  module Optimization
    # High-level optimizer invoked by controllers. Responsibilities:
    #   1. Ensure every stop has coordinates (we can't call Google otherwise).
    #   2. Delegate to GoogleRoutesClient to compute an optimized ordering and distance/duration.
    #   3. Run the capacity simulator on that ordering so we can surface truck/trailer warnings.
    #   4. Merge any warnings/errors into a normalized Result struct for the UI.
    class GoogleOptimizer
      Result = Struct.new(
        :event_ids_in_order,
        :warnings,
        :errors,
        :simulation,
        :total_distance_meters,
        :total_duration_seconds,
        keyword_init: true
      )

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

        optimization_result = routes_client.optimize(stop_payloads)
        return failure_result(optimization_result.errors) unless optimization_result.success?

        event_ids = optimization_result.event_ids_in_order
        simulation = Routes::Optimization::CapacitySimulator.call(route: route, ordered_event_ids: event_ids)

        warnings = Array(optimization_result.warnings)
        warnings.concat(distance_warning(optimization_result))
        warnings.concat(base_warnings(simulation))

        Result.new(
          event_ids_in_order: event_ids,
          warnings: warnings,
          errors: [],
          simulation: simulation,
          total_distance_meters: optimization_result.total_distance_meters,
          total_duration_seconds: optimization_result.total_duration_seconds
        )
      end

      private

      attr_reader :route

      # Lazily instantiate the Google Routes client. Extracted so we can stub it in specs.
      def routes_client
        @routes_client ||= Routes::Optimization::GoogleRoutesClient.new
      end

      # Base query for all events on this route. Sorting by created_at gives deterministic order
      # before Google reorders them.
      def ordered_events
        @ordered_events ||= route.service_events.order(:route_date, :event_type, :created_at)
      end

      def missing_coordinate_events
        ordered_events.reject { |event| stop_coordinate_present?(event) }
      end

      def stop_coordinate_present?(event)
        coords = coordinates_for(event)
        coords[:lat].present? && coords[:lng].present?
      end

      # Helper to read lat/lng regardless of whether the stop is a dump site or a customer location.
      def coordinates_for(event)
        if event.event_type_dump?
          location = event.dump_site&.location
        else
          location = event.order&.location
        end

        {
          lat: location&.lat,
          lng: location&.lng
        }
      end

      # Shape the events for Google: { id:, lat:, lng: }
      def stop_payloads
        ordered_events.map do |event|
          coords = coordinates_for(event)
          { id: event.id, lat: coords[:lat], lng: coords[:lng] }
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
        Result.new(event_ids_in_order: [], warnings: [], errors: Array(errors), simulation: nil,
                   total_distance_meters: nil, total_duration_seconds: nil)
      end

      # Capacity simulator already formats violation strings; just duplicate so callers can mutate safely.
      def base_warnings(simulation)
        simulation.violations.dup
      end

      # Pretty, human-friendly distance/duration string from Google's totals (meters + seconds).
      def distance_warning(result)
        return [] unless result.total_distance_meters.to_i.positive?

        miles = (result.total_distance_meters / 1609.34).round(1)
        duration = result.total_duration_seconds.to_i
        formatted_duration = if duration >= 3600
                               hours = duration / 3600
                               minutes = (duration % 3600) / 60
                               "#{hours}h #{minutes}m"
        else
                               minutes = (duration / 60.0).round
                               "#{minutes}m"
        end

        [ "Estimated drive: #{miles} mi (#{formatted_duration})." ]
      end
    end
  end
end
