module Routes
  # Computes running septage tank usage for each truck across a set of routes.
  class SeptageTracker
    def initialize(routes)
      @routes = Array(routes).compact
    end

    def loads_by_route_id
      @loads_by_route_id ||= begin
        result = {}
        routes_grouped_by_truck.each do |truck, truck_routes|
          truck = truck&.reload
          cumulative = truck&.septage_load_gal.to_i
          capacity = truck&.septage_capacity_gal

          truck_routes.sort_by(&:route_date).each do |route|
            usage = route.capacity_summary.septage_usage[:used]
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
