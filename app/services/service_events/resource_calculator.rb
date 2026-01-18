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
      self.class.trailer_spots_for(units_by_type)
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
      self.class.count_by_slug(units_by_type, 'standard')
    end

    def ada_count
      self.class.count_by_slug(units_by_type, 'ada')
    end

    def handwash_count
      self.class.count_by_slug(units_by_type, 'handwash')
    end

    def units_by_type
      @units_by_type ||= event.units_by_type
    end

    class << self
      def trailer_spots_for(units_by_type)
        base = count_by_slug(units_by_type, 'standard') + (count_by_slug(units_by_type, 'ada') * 2)
        leftover_handwash = [ count_by_slug(units_by_type, 'handwash') - total_toilets(units_by_type), 0 ].max
        base + leftover_handwash
      end

      def count_by_slug(units_by_type, slug)
        units_by_type.sum do |unit_type, quantity|
          unit_type.slug == slug ? quantity.to_i : 0
        end
      end

      def total_toilets(units_by_type)
        count_by_slug(units_by_type, 'standard') + count_by_slug(units_by_type, 'ada')
      end
    end
  end
end
