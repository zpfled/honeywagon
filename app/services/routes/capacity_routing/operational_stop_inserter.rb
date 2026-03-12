module Routes
  module CapacityRouting
    # Decides which operational actions must happen before appending a stop.
    class OperationalStopInserter
      Result = Struct.new(
        :operational_stops,
        :resequence,
        :terminate_route,
        :warnings,
        :errors,
        keyword_init: true
      )

      def initialize(route_state, proposed_stop, config, remaining_stops: [], distance_lookup:)
        @route_state = route_state
        @proposed_stop = proposed_stop
        @config = config
        @remaining_stops = Array(remaining_stops)
        @distance_lookup = distance_lookup
      end

      def call
        result = Result.new(
          operational_stops: [],
          resequence: nil,
          terminate_route: false,
          warnings: [],
          errors: []
        )
        return result unless proposed_stop.is_a?(ServiceEvent)

        delta = ResourceDeltaCalculator.new(proposed_stop, proposed_stop.event_type.to_sym).call
        projected_waste = route_state.waste_gal + delta.dirty_water_gal
        projected_clean = route_state.clean_water_gal + delta.clean_water_gal

        if config.waste_capacity_gal.positive? && projected_waste > config.waste_capacity_gal
          dump_site = nearest_dump_site(route_state.current_position)
          result.operational_stops << build_dump_stop(dump_site) if dump_site
          projected_waste = delta.dirty_water_gal
        end

        if projected_clean < 0 || projected_clean < config.water_min_reserve_gal
          result.operational_stops << build_home_stop(:refill)
          result.terminate_route = true
          return finalize(result)
        end

        evaluate_waste_zone(result, projected_waste, delta)
        evaluate_water_zone(result, projected_clean)
        evaluate_trailer(result, delta)

        finalize(result)
      end

      private

      attr_reader :route_state, :proposed_stop, :config, :remaining_stops, :distance_lookup

      def evaluate_waste_zone(result, projected_waste, delta)
        return unless config.waste_capacity_gal.positive?

        fill = projected_waste / config.waste_capacity_gal
        if fill >= config.waste_red_pct
          dump_site = nearest_dump_site(route_state.current_position)
          return unless dump_site

          next_distance = distance_km(route_state.current_position, proposed_stop.order&.location)
          if next_distance && next_distance <= config.miles_to_km(config.waste_red_nearby_miles)
            return
          end

          result.operational_stops << build_dump_stop(dump_site)
          return
        end

        return unless fill >= config.waste_yellow_pct

        departure = first_outside_dump_proximity
        return unless departure

        waste_at_departure = projected_waste
        in_proximity_segment.each do |stop|
          next unless stop.is_a?(ServiceEvent)
          stop_delta = ResourceDeltaCalculator.new(stop, stop.event_type.to_sym).call
          waste_at_departure += stop_delta.dirty_water_gal
        end
        return unless (waste_at_departure / config.waste_capacity_gal) >= config.waste_red_pct

        dump_site = nearest_dump_site(departure.order&.location || route_state.current_position)
        result.operational_stops << build_dump_stop(dump_site) if dump_site
      end

      def evaluate_water_zone(result, projected_clean)
        return unless config.clean_water_capacity_gal.positive?

        remaining = projected_clean / config.clean_water_capacity_gal
        if remaining <= config.water_red_pct
          next_distance = distance_km(route_state.current_position, proposed_stop.order&.location)
          if next_distance && next_distance <= config.miles_to_km(config.water_red_nearby_miles)
            return
          end

          result.operational_stops << build_home_stop(:refill)
          result.terminate_route = true
          return
        end

        return unless remaining <= config.water_yellow_pct

        departure = first_outside_home_proximity
        return unless departure

        clean_at_departure = projected_clean
        in_home_proximity_segment.each do |stop|
          next unless stop.is_a?(ServiceEvent)
          stop_delta = ResourceDeltaCalculator.new(stop, stop.event_type.to_sym).call
          clean_at_departure += stop_delta.clean_water_gal
        end

        return unless (clean_at_departure / config.clean_water_capacity_gal) <= config.water_red_pct ||
                      clean_at_departure < config.water_min_reserve_gal

        result.operational_stops << build_home_stop(:refill)
        result.terminate_route = true
      end

      def evaluate_trailer(result, delta)
        return unless config.trailer_capacity_spots

        case proposed_stop.event_type.to_sym
        when :pickup
          projected_inventory = route_state.trailer_inventory.merge do |slug, current, _|
            current.to_i
          end
          delta.units_by_slug.each do |slug, qty|
            projected_inventory[slug.to_sym] = projected_inventory[slug.to_sym].to_i + qty.to_i
          end
          used = trailer_spaces_for(projected_inventory)
          return if used <= config.trailer_capacity_spots

          delivery = closest_delivery_that_frees_capacity(projected_inventory)
          if delivery && closer_than_home?(delivery.order&.location)
            result.resequence = { stop_id: delivery.id, reason: :free_trailer_space }
          else
            result.operational_stops << build_home_stop(:reload)
            result.terminate_route = true
          end
        when :delivery
          missing_slug = missing_inventory_slug(delta.units_by_slug)
          if missing_slug
            result.errors << {
              type: 'delivery_inventory_shortfall',
              stop_id: proposed_stop.id,
              missing_unit_type: missing_slug.to_s
            }
            nil
          end
        end
      end

      def finalize(result)
        result.operational_stops = dedupe_and_order(result.operational_stops)
        result
      end

      def dedupe_and_order(stops)
        unique = []
        seen = {}
        stops.each do |stop|
          key = [ stop[:type], stop[:dump_site_id], stop[:reason] ]
          next if seen[key]

          seen[key] = true
          unique << stop
        end

        unique.sort_by do |stop|
          loc = stop[:location] || stop[:dump_site]&.location || config.home_base
          distance_km(route_state.current_position, loc) || Float::INFINITY
        end
      end

      def first_outside_dump_proximity
        threshold_km = config.miles_to_km(config.waste_early_dump_proximity_miles)
        remaining_stops.find do |stop|
          next false unless stop.is_a?(ServiceEvent)
          dump_site = nearest_dump_site(stop.order&.location)
          next false unless dump_site
          distance_km(stop.order&.location, dump_site.location).to_f > threshold_km
        end
      end

      def in_proximity_segment
        threshold_km = config.miles_to_km(config.waste_early_dump_proximity_miles)
        segment = []
        remaining_stops.each do |stop|
          break unless stop.is_a?(ServiceEvent)
          dump_site = nearest_dump_site(stop.order&.location)
          break unless dump_site
          break if distance_km(stop.order&.location, dump_site.location).to_f > threshold_km

          segment << stop
        end
        segment
      end

      def first_outside_home_proximity
        threshold_km = config.miles_to_km(config.water_early_refill_proximity_miles)
        remaining_stops.find do |stop|
          next false unless stop.is_a?(ServiceEvent)
          distance_km(stop.order&.location, config.home_base).to_f > threshold_km
        end
      end

      def in_home_proximity_segment
        threshold_km = config.miles_to_km(config.water_early_refill_proximity_miles)
        segment = []
        remaining_stops.each do |stop|
          break unless stop.is_a?(ServiceEvent)
          break if distance_km(stop.order&.location, config.home_base).to_f > threshold_km
          segment << stop
        end
        segment
      end

      def missing_inventory_slug(required_by_slug)
        required_by_slug.each do |slug, qty|
          return slug if route_state.trailer_inventory[slug].to_i < qty.to_i
        end
        nil
      end

      def closest_delivery_that_frees_capacity(projected_inventory)
        remaining_stops
          .select { |stop| stop.is_a?(ServiceEvent) && stop.event_type_delivery? }
          .find do |stop|
            delta = ResourceDeltaCalculator.new(stop, :delivery).call
            simulated = projected_inventory.dup
            delta.units_by_slug.each do |slug, qty|
              simulated[slug.to_sym] = [ simulated[slug.to_sym].to_i - qty.to_i, 0 ].max
            end
            trailer_spaces_for(simulated) <= config.trailer_capacity_spots
          end
      end

      def closer_than_home?(candidate_location)
        return false unless candidate_location && config.home_base

        candidate_distance = distance_km(route_state.current_position, candidate_location)
        home_distance = distance_km(route_state.current_position, config.home_base)
        return false unless candidate_distance && home_distance

        candidate_distance < home_distance
      end

      def nearest_dump_site(from_location)
        return nil unless from_location

        config.dump_sites.min_by do |site|
          distance_km(from_location, site.location) || Float::INFINITY
        end
      end

      def build_dump_stop(dump_site)
        return nil unless dump_site

        {
          type: :dump,
          dump_site_id: dump_site.id,
          estimated_waste_gal: route_state.waste_gal.to_i,
          location: dump_site.location,
          dump_site: dump_site
        }
      end

      def build_home_stop(reason)
        {
          type: :home_base,
          reason: reason,
          location: config.home_base
        }
      end

      def distance_km(from, to)
        return nil unless from && to

        distance_lookup.distance_km(from: from, to: to)
      end

      def trailer_spaces_for(inventory)
        standard = inventory[:standard].to_i
        ada = inventory[:ada].to_i
        handwash = inventory[:handwash].to_i
        nesting_count = standard + ada
        handwash_spaces = [ handwash - nesting_count, 0 ].max
        (standard * 1) + (ada * 3) + handwash_spaces
      end
    end
  end
end
