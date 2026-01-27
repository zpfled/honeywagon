module ServiceEvents
  # Computes the physical resource requirements for a service event.
  class ResourceCalculator
    attr_reader :event

    def initialize(event)
      @event = event # Keep the event reference for all usage calculations.
    end

    def usage
      {
        trailer_spots: trailer_spots_usage, # Trailer spots needed for delivery/pickup events.
        clean_water_gallons: clean_water_usage, # Clean water gallons required for this event.
        waste_gallons: waste_usage # Waste gallons produced by this event.
      }
    end

    private

    def trailer_spots_usage
      return 0 unless event.event_type_delivery? || event.event_type_pickup? # Services don't move units.

      self.class.trailer_spots_for(units_by_type) # Convert unit counts into trailer spot usage.
    end

    def clean_water_usage
      ServiceEvents::CleanGallonsEstimator.call(event) # Delegate clean water usage estimation.
    end

    def waste_usage
      ServiceEvents::WasteGallonsEstimator.call(event) # Use estimator for waste generated on this event.
    end

    def total_toilets
      standard_count + ada_count # Total number of toilet units.
    end

    def standard_count
      self.class.count_by_slug(units_by_type, 'standard') # Count standard units.
    end

    def ada_count
      self.class.count_by_slug(units_by_type, 'ada') # Count ADA units (2 spots each).
    end

    def handwash_count
      self.class.count_by_slug(units_by_type, 'handwash') # Count handwash units.
    end

    def units_by_type
      @units_by_type ||= event.units_by_type # Cache unit breakdown for repeated use.
    end

    class << self
      def trailer_spots_for(units_by_type)
        base = count_by_slug(units_by_type, 'standard') + (count_by_slug(units_by_type, 'ada') * 2) # ADA counts as 2 spots.
        leftover_handwash = [ count_by_slug(units_by_type, 'handwash') - total_toilets(units_by_type), 0 ].max # Handwash beyond toilets uses extra spots.
        base + leftover_handwash # Total trailer spots needed.
      end

      def count_by_slug(units_by_type, slug)
        units_by_type.sum do |unit_type, quantity| # Aggregate quantities matching the slug.
          unit_type.slug == slug ? quantity.to_i : 0 # Count only matching unit types.
        end
      end

      def total_toilets(units_by_type)
        count_by_slug(units_by_type, 'standard') + count_by_slug(units_by_type, 'ada') # Standard + ADA toilets.
      end
    end
  end
end
