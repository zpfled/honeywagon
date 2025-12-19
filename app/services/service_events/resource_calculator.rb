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
        septage_gallons: septage_usage
      }
    end

    private

    def trailer_spots_usage
      return 0 unless event.event_type_delivery? || event.event_type_pickup?

      base = standard_count + (ada_count * 2)
      leftover_handwash = [ handwash_count - total_toilets, 0 ].max
      base + leftover_handwash
    end

    def clean_water_usage
      case event.event_type.to_sym
      when :delivery
        (total_toilets * 5) + (handwash_count * 20)
      when :service
        total_toilets * 7
      when :pickup
        total_toilets * 1
      else
        0
      end
    end

    def septage_usage
      event.estimated_gallons_pumped
    end

    def total_toilets
      standard_count + ada_count
    end

    def standard_count
      unit_counts['standard'] || 0
    end

    def ada_count
      unit_counts['ada'] || 0
    end

    def handwash_count
      unit_counts['handwash'] || 0
    end

    def unit_counts
      @unit_counts ||= begin
        return {} unless event.order
        order_items = event.order.rental_line_items.includes(:unit_type)
        order_items.each_with_object(Hash.new(0)) do |item, memo|
          slug = item.unit_type&.slug
          next unless slug
          memo[slug] += item.quantity.to_i
        end
      end
    end
  end
end
