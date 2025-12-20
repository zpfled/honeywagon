module Routes
  # Aggregates truck/trailer capacity usage for a route.
  class CapacitySummary
    attr_reader :route, :usage

    def initialize(route:)
      @route = route
      @usage = aggregate_usage
    end

    def trailer_usage
      {
        used: usage[:trailer_spots],
        capacity: route.trailer&.capacity_spots
      }
    end

    def clean_water_usage
      {
        used: usage[:clean_water_gallons],
        capacity: route.truck&.clean_water_capacity_gal
      }
    end

    def waste_usage
      {
        used: usage[:waste_gallons],
        capacity: route.truck&.waste_capacity_gal
      }
    end

    def over_capacity?
      over_capacity_dimensions.any?
    end

    def over_capacity_dimensions
      [].tap do |dims|
        dims << :trailer if over?(trailer_usage)
        dims << :clean_water if over?(clean_water_usage)
        dims << :waste if over?(waste_usage)
      end
    end

    private

    def aggregate_usage
      events = route.service_events.scheduled
      events = events.includes(order: { rental_line_items: :unit_type }) unless events.loaded?

      events.each_with_object({ trailer_spots: 0, clean_water_gallons: 0, waste_gallons: 0 }) do |event, memo|
        usage = ServiceEvents::ResourceCalculator.new(event).usage
        memo[:trailer_spots] += usage[:trailer_spots]
        memo[:clean_water_gallons] += usage[:clean_water_gallons]
        memo[:waste_gallons] += usage[:waste_gallons]
      end
    end

    def over?(record)
      capacity = record[:capacity]
      return false if capacity.nil?

      record[:used] > capacity
    end
  end
end
