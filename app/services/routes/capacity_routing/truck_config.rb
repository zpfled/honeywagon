module Routes
  module CapacityRouting
    # Immutable algorithm config built from truck/trailer/company with defaults.
    class TruckConfig
      KM_PER_MILE = 1.60934

      attr_reader :truck, :trailer, :company, :home_base, :dump_sites

      def initialize(truck:, trailer:, company:)
        @truck = truck
        @trailer = trailer
        @company = company
        @home_base = company.home_base
        @dump_sites = company.dump_sites.includes(:location).to_a
      end

      def waste_capacity_gal
        truck&.waste_capacity_gal.to_f
      end

      def clean_water_capacity_gal
        truck&.clean_water_capacity_gal.to_f
      end

      def trailer_capacity_spots
        trailer&.capacity_spots
      end

      def waste_yellow_pct
        pct_to_ratio(truck&.waste_yellow_threshold_pct, 0.65)
      end

      def waste_red_pct
        fallback = (company.dump_threshold_percent.to_f / 100.0)
        pct_to_ratio(truck&.waste_red_threshold_pct, fallback)
      end

      def waste_red_nearby_miles
        numeric_or_default(truck&.waste_red_nearby_miles, 5.0)
      end

      def waste_early_dump_proximity_miles
        numeric_or_default(truck&.waste_early_dump_proximity_miles, 10.0)
      end

      def waste_min_dump_threshold_pct
        0.25
      end

      def waste_end_of_route_detour_minutes
        15
      end

      def water_yellow_pct
        pct_to_ratio(truck&.water_yellow_threshold_pct, 0.35)
      end

      def water_red_pct
        pct_to_ratio(truck&.water_red_threshold_pct, 0.15)
      end

      def water_red_nearby_miles
        numeric_or_default(truck&.water_red_nearby_miles, 5.0)
      end

      def water_early_refill_proximity_miles
        numeric_or_default(truck&.water_early_refill_proximity_miles, 10.0)
      end

      def water_min_reserve_gal
        numeric_or_default(truck&.water_min_reserve_gal, 10.0)
      end

      def miles_to_km(miles)
        miles.to_f * KM_PER_MILE
      end

      private

      def pct_to_ratio(value, default)
        return default if value.blank?

        value.to_f / 100.0
      end

      def numeric_or_default(value, default)
        value.present? ? value.to_f : default
      end
    end
  end
end
