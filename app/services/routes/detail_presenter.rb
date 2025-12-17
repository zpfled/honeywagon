module Routes
  class DetailPresenter
    attr_reader :route, :service_events

    def initialize(route, company:)
      @route = route
      @company = company
      @service_events = route.service_events.includes(order: [ :customer, :location, { rental_line_items: :unit_type } ])
    end

    def previous_route
      @previous_route ||= company.routes.where('route_date < ?', route.route_date).order(route_date: :desc).first
    end

    def next_route
      @next_route ||= company.routes.where('route_date > ?', route.route_date).order(:route_date).first
    end

    def septage_load
      return unless route.truck_id

      @septage_load ||= begin
        routes = company.routes
                         .where(truck_id: route.truck_id)
                         .where('route_date <= ?', route.route_date)
                         .includes(service_events: { order: { rental_line_items: :unit_type } })
        Routes::SeptageTracker.new(routes).loads_by_route_id[route.id]
      end
    end

    private

    attr_reader :company
  end
end
