module Routes
  module Optimization
    # Performs a Google Routes call using a user-provided ordering.
    # Validates ownership and coordinates before requesting legs/totals.
    class ManualRun
      Result = Struct.new(
        :success?,
        :event_ids_in_order,
        :warnings,
        :errors,
        :total_distance_meters,
        :total_duration_seconds,
        :legs,
        keyword_init: true
      )

      def initialize(route, ordered_event_ids)
        @route = route
        @ordered_event_ids = Array(ordered_event_ids).compact
      end

      def self.call(route, ordered_event_ids)
        new(route, ordered_event_ids).call
      end

      def call
        errors = validation_errors
        return failure_result(errors) if errors.any?

        client_result = routes_client.optimize(stop_payloads, optimize_waypoint_order: false)
        return failure_result(client_result.errors) unless client_result.success?

        persist_metrics(client_result)

        Result.new(
          success?: true,
          event_ids_in_order: ordered_event_ids,
          warnings: client_result.warnings,
          errors: [],
          total_distance_meters: client_result.total_distance_meters,
          total_duration_seconds: client_result.total_duration_seconds,
          legs: client_result.legs
        )
      end

      private

      attr_reader :route, :ordered_event_ids

      def routes_client
        @routes_client ||= Routes::Optimization::GoogleRoutesClient.new
      end

      def events_by_id
        @events_by_id ||= route.service_events.where(id: ordered_event_ids).index_by(&:id)
      end

      def validation_errors
        errors = []

        base = route.company&.home_base
        if base.nil?
          errors << 'Company location is not configured.'
        elsif base.lat.blank? || base.lng.blank?
          errors << 'Company location is missing latitude/longitude.'
        end

        missing_ids = ordered_event_ids - events_by_id.keys
        errors << 'Some service events are invalid for this route.' if missing_ids.any?

        events_by_id.values.each do |event|
          coords = coordinates_for(event)
          next if coords[:lat].present? && coords[:lng].present?

          errors << "#{event_label(event)} is missing latitude/longitude"
        end

        errors
      end

      def coordinates_for(event)
        location = if event.event_type_dump?
                     event.dump_site&.location
        else
                     event.order&.location
        end

        {
          lat: location&.lat,
          lng: location&.lng
        }
      end

      def stop_payloads
        base = route.company.home_base
        base_stop = { id: nil, lat: base.lat, lng: base.lng }
        ordered_events = ordered_event_ids.map { |id| events_by_id[id] }.compact
        event_stops = ordered_events.map do |event|
          coords = coordinates_for(event)
          { id: event.id, lat: coords[:lat], lng: coords[:lng] }
        end

        [ base_stop, *event_stops, base_stop ]
      end

      def event_label(event)
        if event.event_type_dump?
          "Dump event #{event.id}"
        else
          customer_name = event.order&.customer&.display_name || 'Unknown customer'
          "#{event.event_type.titleize} for #{customer_name}"
        end
      end

      def persist_metrics(result)
        route.record_drive_metrics(
          seconds: result.total_duration_seconds.to_i,
          meters: result.total_distance_meters.to_i
        )
        route.record_stop_drive_metrics(event_ids: ordered_event_ids, legs: result.legs)
      end

      def failure_result(errors)
        Result.new(
          success?: false,
          event_ids_in_order: [],
          warnings: [],
          errors: Array(errors),
          total_distance_meters: nil,
          total_duration_seconds: nil,
          legs: []
        )
      end
    end
  end
end
