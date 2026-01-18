module Routes
  class GoogleCalendarPusher
    Result = Struct.new(:success?, :errors, :warnings, keyword_init: true)

    def initialize(route:, user:)
      @route = route
      @user = user
    end

    def call
      return Result.new(success?: false, errors: [ 'Google Calendar is not connected.' ], warnings: []) unless user.google_calendar_connected?

      events = route.service_events
                    .order(:route_sequence, :created_at)
                    .includes(
        order: [ :customer, :location, { rental_line_items: :unit_type }, { service_line_items: :rate_plan } ],
        service_event_units: :unit_type,
        dump_site: :location
      )
      sync_hash = route.google_calendar_hash

      calendar_client = Google::CalendarClient.new(user)
      events.each_with_index do |event, index|
        calendar_client.upsert_event(
          event,
          route_date: route.route_date,
          summary: summary_for(event, index + 1),
          description: description_for(event),
          location: location_for(event)
        )
      end

      route.update_column(:google_calendar_sync_hash, sync_hash)
      Result.new(success?: true, errors: [], warnings: [])
    rescue Google::Apis::AuthorizationError
      Result.new(success?: false, errors: [ 'Google authorization expired. Please reconnect your calendar.' ], warnings: [])
    rescue Google::Apis::Error => e
      Result.new(success?: false, errors: [ e.message ], warnings: [])
    end

    private

    attr_reader :route, :user

    def summary_for(event, position)
      label = event.event_type.to_s.humanize
      name = if event.event_type_dump?
               event.dump_site&.name || 'Dump site'
      elsif event.event_type_refill?
               'Home base'
      else
               event.order&.customer&.display_name || 'Customer'
      end
      "#{position} - #{label} - #{name}"
    end

    def description_for(event)
      lines = []
      lines << "Event type: #{event.event_type.to_s.humanize}"
      lines << "Scheduled on: #{event.scheduled_on}" if event.scheduled_on
      lines << "Route date: #{route.route_date}"
      lines << "Customer: #{event.order&.customer&.display_name}" if event.order
      lines << "Location: #{event.order&.location&.full_address}" if event.order&.location

      unit_lines = units_for(event)
      lines << "Units: #{unit_lines.join(', ')}" if unit_lines.any?

      service_lines = service_items_for(event)
      lines << "Services: #{service_lines.join(', ')}" if service_lines.any?

      lines.compact.join("\n")
    end

    def location_for(event)
      if event.event_type_dump?
        event.dump_site&.location&.full_address
      elsif event.event_type_refill?
        route.company&.home_base&.full_address
      else
        event.order&.location&.full_address
      end
    end

    def units_for(event)
      event.units_by_type.map do |unit_type, quantity|
        next if unit_type.blank?
        "#{quantity}x #{unit_type.name}"
      end.compact
    end

    def service_items_for(event)
      return [] unless event.order && event.event_type_service?

      event.order.service_line_items.map do |item|
        label = item.description.presence || 'Service'
        units = item.units_serviced.to_i
        units.positive? ? "#{label} (#{units})" : label
      end
    end
  end
end
