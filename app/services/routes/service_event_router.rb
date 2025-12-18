# frozen_string_literal: true

module Routes
  # ServiceEventRouter finds or creates an appropriate route for a service event,
  # auto-assigning the smallest trailer that can satisfy delivery/pickup needs.
  class ServiceEventRouter
    WINDOW = 2.days

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

    def initialize(event)
      @event = event
      @company = event.order&.company
    end

    def call
      return if self.class.auto_assignment_disabled?
      return unless company && event.scheduled_on
      return unless company.trucks.exists?

      route = target_route
      attrs = { route: route }
      attrs[:route_date] = event.logistics_locked? ? event.scheduled_on : route.route_date
      event.update!(attrs)
      route
    end

    private

    attr_reader :event, :company

    def target_route
      if event.logistics_locked?
        exact_route || create_route(event.scheduled_on)
      else
        find_matching_route || create_route(event.scheduled_on)
      end
    end

    def find_matching_route
      range = (event.scheduled_on - WINDOW)..(event.scheduled_on + WINDOW)
      company.routes
             .where(route_date: range)
             .order(Arel.sql("ABS(route_date - DATE '#{event.scheduled_on}')"))
             .first
    end

    def exact_route
      company.routes.find_by(route_date: event.scheduled_on)
    end

    def create_route(date)
      company.routes.create!(
        route_date: date,
        truck: company.trucks.order(:created_at).first,
        trailer: default_trailer
      )
    end

    def default_trailer
      return nil unless requires_trailer?

      trailers = company.trailers.order(:capacity_spots)
      trailers.find { |trailer| trailer.capacity_spots >= required_trailer_spots } || trailers.last
    end

    def requires_trailer?
      required_trailer_spots.positive?
    end

    def required_trailer_spots
      @required_trailer_spots ||= ServiceEvents::ResourceCalculator.new(event).usage[:trailer_spots]
    end
  end
end
