# frozen_string_literal: true

module Routes
  # BackfillServiceEvents assigns scheduled service events without a route to
  # existing or newly created routes. Events within +/-2 days of a route_date
  # join the pending route; others spawn new routes dated at scheduled_on.
  class BackfillServiceEvents
    WINDOW = ServiceEventRouter::WINDOW

    def initialize(company:)
      @company = company
    end
    def call
      assigned = 0
      created_routes = 0

      unrouted_events.find_each do |event|
        route = find_matching_route(event) || create_route_for(event)
        created_routes += 1 if route.previous_changes.key?('id')

        event.update!(route: route, route_date: route.route_date)
        assigned += 1
      end

      [ assigned, created_routes ]
    end

    private

    attr_reader :company

    def unrouted_events
      company.service_events.scheduled.where(route_id: nil)
    end

    def find_matching_route(event)
      target_date = event.scheduled_on
      range = (target_date - WINDOW)..(target_date + WINDOW)
      company.routes
             .where(route_date: range)
             .order(Arel.sql("ABS(route_date - DATE '#{target_date}')"))
             .first
    end

    def create_route_for(event)
      company.routes.create!(route_date: event.scheduled_on)
    end
  end
end
