module Routes
  module CapacityRouting
    # Computes per-stop clean/waste deltas from unit type coefficients.
    class ResourceDeltaCalculator
      Result = Struct.new(:dirty_water_gal, :clean_water_gal, :units_by_slug, keyword_init: true)

      def initialize(stop, event_type)
        @stop = stop
        @event_type = event_type.to_sym
      end

      def call
        dirty = 0.0
        clean = 0.0
        units_by_slug = Hash.new(0)

        unit_counts.each do |unit_type, quantity|
          qty = quantity.to_i
          next if qty <= 0

          units_by_slug[unit_type.slug.to_sym] += qty
          clean += clean_delta_for(unit_type) * qty
          dirty += dirty_delta_for(unit_type) * qty
        end

        Result.new(
          dirty_water_gal: dirty,
          clean_water_gal: clean,
          units_by_slug: units_by_slug
        )
      end

      private

      attr_reader :stop, :event_type

      def unit_counts
        stop.units_by_type
      end

      def clean_delta_for(unit_type)
        case event_type
        when :delivery then -unit_type.delivery_clean_gallons.to_f
        when :service then -unit_type.service_clean_gallons.to_f
        when :pickup then -unit_type.pickup_clean_gallons.to_f
        else
          0.0
        end
      end

      def dirty_delta_for(unit_type)
        case event_type
        when :service then unit_type.service_waste_gallons.to_f
        when :pickup then unit_type.pickup_waste_gallons.to_f
        else
          0.0
        end
      end
    end
  end
end
