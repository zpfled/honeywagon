module Routes
  # Presents per-route data for the dashboard table (alerts, cadence, badges).
  class DashboardRowPresenter
    attr_reader :route, :septage_load

    def initialize(route, septage_load: nil)
      @route = route
      @septage_load = septage_load
    end

    # TODO: Extract workload-related data into Routes::WorkloadSummary and have this presenter delegate.
    def deliveries_count = route.delivery_units_total
    def services_count = route.serviced_units_count
    def pickups_count = route.pickup_units_total
    def estimated_gallons = route.estimated_gallons

    def delivery_badges
      [].tap do |badges|
        if deliveries_overdue_count.positive?
          badges << { text: "#{deliveries_overdue_count} late", tone: :danger }
        end
        if deliveries_due_today_count.positive?
          badges << { text: "#{deliveries_due_today_count} due today", tone: :warning }
        end
      end
    end

    def service_badges
      [].tap do |badges|
        if services_overdue_count.positive?
          badges << { text: "#{services_overdue_count} overdue", tone: :danger }
        end
        if services_due_today_count.positive?
          badges << { text: "#{services_due_today_count} due today", tone: :warning }
        end
      end
    end

    def labeled_badges
      @labeled_badges ||= begin
        badges = []
        badges += delivery_badges.map { |badge| badge.merge(text: "Delivery: #{badge[:text]}") }
        badges += service_badges.map { |badge| badge.merge(text: "Service: #{badge[:text]}") }
        badges
      end
    end

    def alert_badges
      labeled_badges.presence || [ { text: 'On schedule', tone: :success } ]
    end

    def cadence_info
      { last_completed_on: last_service_completed_on, next_due_on: next_service_due_on }
    end

    # TODO: Move capacity/septage alert generation into a dedicated Routes::CapacitySummary service.
    def capacity_icons
      route.over_capacity_dimensions.map do |dimension|
        case dimension
        when :trailer
          { glyph: '⛟', tone: 'text-rose-600', title: 'Trailer capacity exceeded' }
        when :clean_water
          { glyph: '💧', tone: 'text-blue-600', title: 'Clean water capacity exceeded' }
        when :septage
          { glyph: '🛢', tone: 'text-amber-700', title: 'Septage capacity exceeded' }
        end
      end.compact
    end

    def row_background_class
      if deliveries_overdue_count.positive?
        'bg-rose-50'
      elsif services_overdue_count.positive?
        'bg-amber-50'
      else
        nil
      end
    end

    def trend_badge
      count = route.service_event_count
      return { text: '↓ light route', tone: :info } if count <= 2
      return { text: '↑ heavy route', tone: :danger } if count >= 5

      nil
    end

    # TODO: Replace direct septage access with a Routes::SeptageSummary collaborator.
    def septage_load_summary
      return unless septage_load

      septage_load
    end

    # TODO: Extract the per-customer aggregation into a Routes::OrderSummary builder.
    def orders_summary
      route.service_events
           .includes(order: :customer, dump_site: :location)
           .group_by do |event|
             if event.event_type_dump?
               [ :dump, event.dump_site_id ]
             else
               [ :order, event.order_id ]
             end
           end
           .map do |_group_key, events|
             sample = events.first
             if sample.event_type_dump?
               site = sample.dump_site
               {
                 label: site&.name || 'Dump event',
                 detail: site&.location&.display_label,
                 units: 0,
                 dump: true
               }
             else
               order = sample.order
               label = order&.customer&.display_name || order&.location&.display_label || 'Unknown order'
               {
                 label: label,
                 detail: nil,
                 units: events.sum(&:units_impacted_count),
                 dump: false
               }
             end
           end
    end

    private

    def delivery_events
      @delivery_events ||= route.service_events.select(&:event_type_delivery?)
    end

    def service_events
      @service_events ||= route.service_events.select(&:event_type_service?)
    end

    def deliveries_overdue_count
      @deliveries_overdue_count ||= delivery_events.count(&:overdue?)
    end

    def deliveries_due_today_count
      @deliveries_due_today_count ||= delivery_events.count { |event| event.status_scheduled? && event.scheduled_on == Date.current }
    end

    def services_overdue_count
      @services_overdue_count ||= service_events.count(&:overdue?)
    end

    def services_due_today_count
      @services_due_today_count ||= service_events.count { |event| event.status_scheduled? && event.scheduled_on == Date.current }
    end

    def last_service_completed_on
      return if service_orders.empty?

      completed_dates = service_orders.flat_map do |order|
        order.service_events.select { |event| event.event_type_service? && event.completed_on.present? }.map(&:completed_on)
      end

      completed_dates.compact.max
    end

    def next_service_due_on
      dates = service_events.map(&:scheduled_on).compact
      dates.min
    end

    def service_orders
      @service_orders ||= service_events.map(&:order).compact.uniq
    end

    def representative_location
      @representative_location ||= route.service_events.includes(order: :location).map { |event| event.order&.location }.compact.find do |location|
        location.lat.present? && location.lng.present?
      end
    end

    public

    def weather_forecast
      @weather_forecast ||= begin
        location = representative_location
        Weather::ForecastFetcher.call(
          company: route.company,
          date: route.route_date,
          latitude: location&.lat,
          longitude: location&.lng
        )
      end
    end
  end
end
