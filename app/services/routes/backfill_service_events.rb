# frozen_string_literal: true

module Routes
  # Assigns unrouted service events to nearby routes or creates new routes when needed.
  class BackfillServiceEvents
    WINDOW = ServiceEventRouter::WINDOW

    def initialize(company:)
      @company = company
    end

    def call
      assigned = 0
      created_routes = 0

      unrouted_events.find_each do |event|
        route = assign_event(event)
        next unless route

        created_routes += 1 if route.previous_changes.key?('id')
        assigned += 1
      end

      [ assigned, created_routes ]
    end

    private

    attr_reader :company

    def unrouted_events
      company.service_events.scheduled.where(route_id: nil)
    end

    def assign_event(event)
      Routes::ServiceEventRouter.new(event).call
    end
  end
end
