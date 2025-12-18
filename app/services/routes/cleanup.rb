module Routes
  class Cleanup
    def self.destroy_if_empty(route_or_id)
      route = route_or_id.is_a?(Route) ? route_or_id : Route.find_by(id: route_or_id)
      return unless route
      return unless route.service_events.reload.none?

      route.destroy
    end
  end
end
