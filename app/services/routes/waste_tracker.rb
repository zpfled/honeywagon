module Routes
  # Computes running waste tank usage for each truck across a set of routes.
  class WasteTracker
    def initialize(routes)
      # Expect a list of routes across one or more trucks; nils are ignored.
      @routes = Array(routes).compact
      preload_units_for(@routes)
    end

    def ending_loads_by_route_id
      @ending_loads_by_route_id ||= begin
        result = {}
        routes_grouped_by_truck.each do |truck, truck_routes|
          # Start from completed events before the first route date to avoid double counting.
          baseline = baseline_waste_before(truck, truck_routes)
          cumulative = baseline
          capacity = truck&.waste_capacity_gal

          # Walk routes in date order and accumulate waste usage as the route runs.
          truck_routes.sort_by(&:route_date).each do |route|
            # Simulate each route so completed events and dump resets are included.
            cumulative = simulate_route_waste(route, starting_waste: cumulative)
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

    def starting_loads_by_route_id
      @starting_loads_by_route_id ||= begin
        result = {}
        routes_grouped_by_truck.each do |truck, truck_routes|
          # Snapshot the waste load at the start of each route before applying its usage.
          # Baseline is derived from completed events before the first route date.
          cumulative_waste_gal = baseline_waste_before(truck, truck_routes)

          # Sort chronologically so the carryover builds in route order.
          truck_routes.sort_by(&:route_date).each do |route|
            # Starting load for this route is whatever has accumulated so far.
            result[route.id] = cumulative_waste_gal
            # Add waste used on this route to feed into the next route's starting load.
            cumulative_waste_gal = simulate_route_waste(route, starting_waste: cumulative_waste_gal)
          end
        end
        result
      end
    end

    private

    attr_reader :routes

    def routes_grouped_by_truck
      # Capacity is tracked per truck; group the input routes accordingly.
      routes.group_by(&:truck)
    end

    def preload_units_for(routes)
      return if routes.blank?

      events = routes.flat_map(&:service_events).uniq
      return if events.empty?
      return if events.any? { |event| event.service_event_units.loaded? && event.service_event_units.any? }

      ActiveRecord::Associations::Preloader.new(
        records: events,
        associations: { service_event_units: :unit_type }
      ).call
    end

    def simulate_route_waste(route, starting_waste:)
      ordered_ids = route.service_events.order(:route_sequence, :created_at).pluck(:id)
      simulation = Routes::Optimization::CapacitySimulator.call(
        route: route,
        ordered_event_ids: ordered_ids,
        starting_waste_gallons: starting_waste
      )
      simulation.steps.last&.waste_used.to_i
    end

    def baseline_waste_before(truck, truck_routes)
      return 0 unless truck && truck_routes.any?

      earliest_date = truck_routes.map(&:route_date).compact.min
      return 0 unless earliest_date

      events = ServiceEvent
               .joins(:route)
               .where(routes: { truck_id: truck.id })
               .where(status: ServiceEvent.statuses[:completed])
               .where('routes.route_date < ?', earliest_date)
               .order(Arel.sql('routes.route_date ASC, service_events.updated_at ASC'))

      total = 0
      events.each do |event|
        if event.event_type_dump?
          total = 0
        else
          total += event.estimated_gallons_pumped
        end
      end

      total
    end
  end
end
