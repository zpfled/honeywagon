module Routes
  class DetailPresenter
    attr_reader :route, :service_events, :capacity_steps

    def initialize(route, company:)
      @route = route
      @company = company
      @service_events = service_events_for_display
      # TODO: Build stop presenters here to keep view markup-only.
      build_capacity_data
    end

    def previous_route
      @previous_route ||= company.routes.where('route_date < ?', route.route_date).order(route_date: :desc).first
    end

    def next_route
      @next_route ||= company.routes.where('route_date > ?', route.route_date).order(:route_date).first
    end

    def waste_load
      return unless route.truck_id

      @waste_load ||= begin
        routes = company.routes
                         .where(truck_id: route.truck_id)
                         .where('route_date <= ?', route.route_date)
        Routes::WasteTracker.new(routes).ending_loads_by_route_id[route.id]
      end
    end

    def weather_forecast
      # TODO: Guard when no geocoded location; return nil early to avoid noisy calls.
      @weather_forecast ||= begin
        location = representative_location
        Weather::ForecastFetcher.call(
          company: company,
          date: route.route_date,
          latitude: location&.lat,
          longitude: location&.lng
        )
      end
    end

    def stop_presenters
      @stop_presenters ||= service_events.map do |event|
        StopPresenter.new(event, capacity_step: capacity_steps[event.id])
      end
    end

    private

    attr_reader :company
    attr_reader :capacity_result

    def representative_location
      @representative_location ||= service_events.map { |event| event.order&.location }.compact.find do |location|
        location.lat.present? && location.lng.present?
      end
    end

    def build_capacity_data
      events_for_capacity = route.service_events.includes(service_event_units: :unit_type)
      preload_rental_line_items_for(events_for_capacity)
                                      .order(Arel.sql('COALESCE(route_sequence, 0)'), :created_at)
      result = Routes::Optimization::CapacitySimulator.call(
        route: route,
        ordered_event_ids: events_for_capacity.pluck(:id),
        starting_waste_gallons: projected_starting_waste_gallons
      )
      @capacity_result = result
      @capacity_steps = result.steps.index_by(&:event_id)
    rescue StandardError => e
      Rails.logger.warn(
        message: 'Routes::DetailPresenter failed to build capacity data',
        route_id: route.id,
        company_id: company.id,
        error_class: e.class.name,
        error_message: e.message
      )
      # TODO: expose warning via presenter so the view can surface the failure state.
      @capacity_steps = {}
    end

    def service_events_for_display
      events = route.service_events
                    .includes(order: [ :customer, :location ], service_event_units: :unit_type)
                    .order(Arel.sql('COALESCE(route_sequence, 0)'), :created_at)
      preload_rental_line_items_for(events)
      dump_events = events.select(&:event_type_dump?)
      if dump_events.any?
        ActiveRecord::Associations::Preloader.new(
          records: dump_events,
          associations: { dump_site: :location }
        ).call
      end
      events
    end

    def projected_starting_waste_gallons
      # Waste carries over across routes for the same truck until a dump occurs.
      # We compute the starting load by replaying prior routes up to this route date.
      return 0 unless route.truck_id

      routes = company.routes
                      .where(truck_id: route.truck_id)
                      .where('route_date <= ?', route.route_date)
      # WasteTracker returns the waste load at the start of each route in the list.
      Routes::WasteTracker.new(routes).starting_loads_by_route_id[route.id].to_i
    end
    private :projected_starting_waste_gallons

    def preload_rental_line_items_for(events)
      needs_units = events.any? do |event|
        event.order.present? && !event.event_type_dump? && !event.event_type_refill?
      end
      return unless needs_units
      return if events.any? { |event| event.service_event_units.loaded? && event.service_event_units.any? }

      orders = events.filter_map { |event| event.order if event.order.present? }.uniq
      return if orders.empty?
      return unless orders.any? { |order| order.association(:rental_line_items).loaded? ? order.rental_line_items.any? : order.rental_line_items.exists? }

      ActiveRecord::Associations::Preloader.new(records: orders, associations: { rental_line_items: :unit_type }).call
    end
  end
end
