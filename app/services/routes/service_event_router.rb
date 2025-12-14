# frozen_string_literal: true

module Routes
  # ServiceEventRouter assigns an individual service event to a nearby route or
  # creates a new route on the event's scheduled date when none exists.
  class ServiceEventRouter
    class << self
      def without_auto_assignment
        previous = Thread.current[:service_event_router_disabled]
        Thread.current[:service_event_router_disabled] = true
        yield
      ensure
        Thread.current[:service_event_router_disabled] = previous
      end

      def auto_assignment_disabled?
        Thread.current[:service_event_router_disabled]
      end
    end

    WINDOW = 2.days

    def initialize(event)
      @event = event
      @company = event.order&.company
    end

    def call
      return if self.class.auto_assignment_disabled?
      return unless company && event.scheduled_on
      return unless company.trucks.exists?

      route = find_matching_route || create_route
      event.update!(route: route, route_date: route.route_date)
    end

    private

    attr_reader :event, :company

    def find_matching_route
      range = (event.scheduled_on - WINDOW)..(event.scheduled_on + WINDOW)
      company.routes
             .where(route_date: range)
             .order(Arel.sql("ABS(route_date - DATE '#{event.scheduled_on}')"))
             .first
    end

    def create_route
      company.routes.create!(route_date: event.scheduled_on)
    end
  end
end
