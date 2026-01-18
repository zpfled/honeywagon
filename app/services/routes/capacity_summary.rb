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
      events = events.includes(service_event_units: :unit_type).to_a unless events.loaded?
      preload_rental_line_items_for(events)

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

    def preload_rental_line_items_for(events)
      return if events.respond_to?(:loaded?) && !events.loaded?

      orders = events.filter_map do |event|
        next unless event.order.present?
        next unless event.service_event_units.loaded? && event.service_event_units.empty?
        event.order
      end.uniq
      return if orders.empty?

      ActiveRecord::Associations::Preloader.new(records: orders, associations: { rental_line_items: :unit_type }).call
    end
  end
end
