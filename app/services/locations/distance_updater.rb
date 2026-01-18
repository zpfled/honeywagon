module Locations
  # Updates cached distances for a single location within each related company.
  class DistanceUpdater
    EARTH_RADIUS_KM = 6371.0

    def initialize(location)
      @location = location
    end

    def self.call(location)
      new(location).call
    end

    def call
      return unless location.lat.present? && location.lng.present?

      companies_for_location.each do |company|
        locations_for_company(company).each do |target|
          next if target.id == location.id
          next unless target.lat.present? && target.lng.present?

          upsert_distance(company: company, from: location, to: target)
          upsert_distance(company: company, from: target, to: location)
        end
      end
    end

    private

    attr_reader :location

    def companies_for_location
      companies = []
      companies << location.customer&.company if location.customer
      companies.concat(DumpSite.where(location_id: location.id).includes(:company).map(&:company))
      companies.concat(Company.where(home_base_id: location.id))
      companies.compact.uniq
    end

    def locations_for_company(company)
      locations = company.locations.to_a
      locations.concat(company.dump_sites.includes(:location).map(&:location))
      locations << company.home_base if company.home_base
      locations.compact.uniq
    end

    def upsert_distance(company:, from:, to:)
      record = LocationDistance.find_or_initialize_by(from_location: from, to_location: to)
      record.distance_km = haversine_km(from, to)
      record.computed_at = Time.current
      record.save!
    end

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
