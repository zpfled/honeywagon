module Routes
  module CapacityRouting
    # Resolves straight-line distances between locations, falling back to haversine.
    class DistanceLookup
      EARTH_RADIUS_KM = 6371.0

      def initialize(company:)
        @company = company
        @distance_cache = {}
      end

      def distance_km(from:, to:)
        return nil unless from && to
        return nil if from.lat.blank? || from.lng.blank? || to.lat.blank? || to.lng.blank?

        cache_key = [ from.id, to.id ]
        return @distance_cache[cache_key] if @distance_cache.key?(cache_key)

        cached = LocationDistance.find_by(from_location: from, to_location: to)
        return @distance_cache[cache_key] = cached.distance_km.to_f if cached

        @distance_cache[cache_key] = haversine_km(from, to)
      end

      private

      attr_reader :company

      def haversine_km(a, b)
        lat1 = to_radians(a.lat)
        lat2 = to_radians(b.lat)
        delta_lat = lat2 - lat1
        delta_lng = to_radians(b.lng - a.lng)

        h = Math.sin(delta_lat / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(delta_lng / 2)**2
        2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h))
      end

      def to_radians(degrees)
        degrees.to_f * Math::PI / 180.0
      end
    end
  end
end
