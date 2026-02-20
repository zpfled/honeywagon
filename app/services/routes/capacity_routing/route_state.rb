module Routes
  module CapacityRouting
    # Mutable in-memory state for a single route build.
    class RouteState
      attr_reader :waste_gal, :clean_water_gal, :trailer_inventory, :current_position

      def initialize(waste_gal:, clean_water_gal:, current_position:, trailer_inventory: nil)
        @waste_gal = waste_gal.to_f
        @clean_water_gal = clean_water_gal.to_f
        @current_position = current_position
        @trailer_inventory = Hash.new(0)
        merge_inventory!(trailer_inventory || {})
      end

      def apply_stop!(stop, config)
        if stop.is_a?(Hash)
          apply_operational_stop!(stop, config)
          return
        end

        delta = ResourceDeltaCalculator.new(stop, stop.event_type.to_sym).call
        @waste_gal += delta.dirty_water_gal.to_f
        @clean_water_gal += delta.clean_water_gal.to_f

        case stop.event_type.to_sym
        when :pickup
          merge_inventory!(delta.units_by_slug)
        when :delivery
          subtract_inventory!(delta.units_by_slug)
        end

        @current_position = stop.order&.location || current_position
      end

      def apply_dump!
        @waste_gal = 0.0
      end

      def apply_refill!(config)
        @clean_water_gal = config.clean_water_capacity_gal
      end

      def apply_reload!(units_hash)
        merge_inventory!(units_hash)
      end

      def waste_fill_pct(config)
        return 0.0 if config.waste_capacity_gal.to_f <= 0

        @waste_gal / config.waste_capacity_gal.to_f
      end

      def water_remaining_pct(config)
        return 1.0 if config.clean_water_capacity_gal.to_f <= 0

        @clean_water_gal / config.clean_water_capacity_gal.to_f
      end

      def trailer_spaces_used
        standard = trailer_inventory[:standard].to_i
        ada = trailer_inventory[:ada].to_i
        handwash = trailer_inventory[:handwash].to_i
        nesting_count = standard + ada
        handwash_spaces = [ handwash - nesting_count, 0 ].max
        (standard * 1) + (ada * 3) + handwash_spaces
      end

      private

      def apply_operational_stop!(stop, config)
        case stop[:type]
        when :dump
          apply_dump!
          @current_position = stop[:location] || stop[:dump_site]&.location || current_position
        when :home_base
          apply_refill!(config) if %i[refill both].include?(stop[:reason])
          # Known edge case for follow-up: trailer reload units currently reset to
          # empty inventory because home inventory counts are not modeled yet.
          @trailer_inventory = Hash.new(0) if %i[reload both].include?(stop[:reason])
          @current_position = stop[:location] || config.home_base || current_position
        end
      end

      def merge_inventory!(incoming)
        incoming.each do |slug, qty|
          @trailer_inventory[slug.to_sym] += qty.to_i
        end
      end

      def subtract_inventory!(outgoing)
        outgoing.each do |slug, qty|
          key = slug.to_sym
          @trailer_inventory[key] = [ @trailer_inventory[key].to_i - qty.to_i, 0 ].max
        end
      end
    end
  end
end
