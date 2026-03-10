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
      return [ 0, 0 ] unless company.trucks.exists?

      assigned = 0
      created_routes = 0

      unrouted_events.find_each do |event|
        route = target_route_for(event)
        created_routes += 1 if route.previous_changes.key?('id')

        stop = RouteStop.find_or_initialize_by(service_event: event)
        stop.route = route
        stop.position ||= route.route_stops.maximum(:position).to_i + 1
        stop.status = event.status
        stop.save!
        route.synchronize_route_sequence_with_stops!
        assigned += 1
      end

      [ assigned, created_routes ]
    end

    private

    attr_reader :company

    def unrouted_events
      company.service_events.scheduled.left_outer_joins(:route_stops).where(route_stops: { id: nil })
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
