module Routes
  class IndexPresenter
    def initialize(routes)
      @routes = Array(routes)
    end

    def rows
      @rows ||= routes.map { |route| Row.new(route) }
    end

    private

    attr_reader :routes

    class Row
      attr_reader :route

      def initialize(route)
        @route = route
        @events = route.service_events.to_a
      end

      def service_event_count
        events.size
      end

      def estimated_gallons
        events.sum(&:estimated_gallons_pumped)
      end

      def deliveries_count
        events.count(&:event_type_delivery?)
      end

      def services_count
        events.count(&:event_type_service?)
      end

      def pickups_count
        events.count(&:event_type_pickup?)
      end

      def over_capacity?
        route.over_capacity?
      end

      def over_capacity_dimensions
        route.over_capacity_dimensions
      end

      private

      attr_reader :events
    end
  end
end
