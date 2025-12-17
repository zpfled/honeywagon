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

    private

    attr_reader :company
  end
end
