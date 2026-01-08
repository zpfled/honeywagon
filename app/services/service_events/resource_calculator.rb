module ServiceEvents
  # Computes the physical resource requirements for a service event.
  class ResourceCalculator
    attr_reader :event

    def initialize(event)
      @event = event
    end

    def usage
      {
        trailer_spots: trailer_spots_usage,
        clean_water_gallons: clean_water_usage,
        waste_gallons: waste_usage
      }
    end

    private

    def trailer_spots_usage
      return 0 unless event.event_type_delivery? || event.event_type_pickup?

      # TODO: Make this magic number 2 a meaningful constant
      base = standard_count + (ada_count * 2)
      leftover_handwash = [ handwash_count - total_toilets, 0 ].max
      base + leftover_handwash
    end

    def clean_water_usage
      case event.event_type.to_sym
      when :delivery
        sum_by_unit_type(:delivery_clean_gallons)
      when :service
        sum_by_unit_type(:service_clean_gallons)
      when :pickup
        sum_by_unit_type(:pickup_clean_gallons)
      else
        0
      end
    end

    def waste_usage
      event.estimated_gallons_pumped
    end

    def sum_by_unit_type(field)
      units_by_type.sum do |unit_type, quantity|
        per_unit = unit_type.public_send(field).to_i
        per_unit * quantity
      end
    end

    def total_toilets
      standard_count + ada_count
    end

    def standard_count
      count_by_slug('standard')
    end

    def ada_count
      count_by_slug('ada')
    end

    def handwash_count
      count_by_slug('handwash')
    end

    def count_by_slug(slug)
      units_by_type.sum do |unit_type, quantity|
        unit_type.slug == slug ? quantity : 0
      end
    end

    def units_by_type
      @units_by_type ||= begin
        return {} unless event.order
        event.order.rental_line_items.each_with_object(Hash.new(0)) do |item, memo|
          unit_type = item.unit_type
          next unless unit_type
          memo[unit_type] += item.quantity.to_i
        end
      end
    end
  end
end
