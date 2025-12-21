module Routes
  # Computes running waste tank usage for each truck across a set of routes.
  class WasteTracker
    def initialize(routes)
      @routes = Array(routes).compact
    end

    def loads_by_route_id
      @loads_by_route_id ||= begin
        result = {}
        routes_grouped_by_truck.each do |truck, truck_routes|
          truck = truck&.reload
          cumulative = truck&.waste_load_gal.to_i
          capacity = truck&.waste_capacity_gal

          truck_routes.sort_by(&:route_date).each do |route|
            usage = route.capacity_summary.waste_usage[:used]
            cumulative += usage
            result[route.id] = {
              cumulative_used: cumulative,
              capacity: capacity,
              remaining: capacity.nil? ? nil : capacity - cumulative,
              over_capacity: capacity.present? && cumulative > capacity
            }
          end
        end
        result
      end
    end

    private

    attr_reader :routes

    def routes_grouped_by_truck
      routes.group_by(&:truck)
    end
  end
end
