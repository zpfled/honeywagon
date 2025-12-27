module Routes
  class DetailPresenter
    attr_reader :route, :service_events, :capacity_steps

    def initialize(route, company:)
      @route = route
      @company = company
      @service_events = route.service_events
                               .includes(order: [ :customer, :location, { rental_line_items: :unit_type } ])
                               .order(Arel.sql('COALESCE(route_sequence, 0)'), :created_at)
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
                         .includes(service_events: { order: { rental_line_items: :unit_type } })
        Routes::WasteTracker.new(routes).loads_by_route_id[route.id]
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

    private

    attr_reader :company
    attr_reader :capacity_result

    def representative_location
      @representative_location ||= service_events.map { |event| event.order&.location }.compact.find do |location|
        location.lat.present? && location.lng.present?
      end
    end

    def build_capacity_data
      result = Routes::Optimization::CapacitySimulator.call(
        route: route,
        ordered_event_ids: service_events.pluck(:id)
      )
      @capacity_result = result
      @capacity_steps = result.steps.index_by(&:event_id)
    rescue StandardError
      # TODO: Log/report failure so capacity issues surface; expose warning via presenter.
      @capacity_steps = {}
    end
  end
end
