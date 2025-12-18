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
        route = target_route_for(event)
        created_routes += 1 if route.previous_changes.key?('id')

        attributes = { route: route }
        attributes[:route_date] = event.logistics_locked? ? event.scheduled_on : route.route_date
        event.update!(attributes)
        assigned += 1
      end

      [ assigned, created_routes ]
    end

    private

    attr_reader :company

    def unrouted_events
      company.service_events.scheduled.where(route_id: nil)
    end

    def target_route_for(event)
      if event.logistics_locked?
        company.routes.find_by(route_date: event.scheduled_on) || company.routes.create!(route_date: event.scheduled_on)
      else
        find_matching_route(event) || company.routes.create!(route_date: event.scheduled_on)
      end
    end

    def find_matching_route(event)
      target_date = event.scheduled_on
      range = (target_date - WINDOW)..(target_date + WINDOW)
      company.routes
             .where(route_date: range)
             .order(Arel.sql("ABS(route_date - DATE '#{target_date}')"))
             .first
    end
  end
end
