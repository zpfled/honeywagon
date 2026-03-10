module Routes
  class Lifecycle
    class << self
      def after_route_create(route)
        assign_pending_events(route)
      end

      def after_route_update(route)
        assign_pending_events(route) if route.saved_change_to_route_date?
      end

      def after_service_event_change(event, previous_route_id: nil)
        cleanup_route(previous_route_id)
        cleanup_route(event.route&.id)
      end

      def cleanup_route(route_or_id)
        route = route_or_id.is_a?(Route) ? route_or_id : Route.find_by(id: route_or_id)
        return unless route
        return unless route.route_stops.reload.none?

        route.destroy
      end

      private

      def assign_pending_events(route)
        return if route.skip_auto_assign || Route.auto_assignment_disabled?

        window = route.route_date.beginning_of_week..route.route_date.end_of_week
        route.company.service_events
             .scheduled
             .left_outer_joins(:route_stops)
             .where(route_stops: { id: nil })
             .where(scheduled_on: window)
             .find_each do |event|
          next unless logistics_window_allows?(event, route.route_date)

          RouteStop.create!(
            route: route,
            service_event: event,
            position: route.route_stops.maximum(:position).to_i + 1,
            status: event.status
          )
          event.update!(scheduled_on: route.route_date) if event.event_type_delivery?
        end
      end

      def logistics_window_allows?(event, target_date)
        return true unless event.logistics_locked?

        if event.event_type_delivery?
          target_date <= event.scheduled_on
        elsif event.event_type_pickup?
          target_date >= event.scheduled_on
        else
          true
        end
      end
    end
  end
end
