module Routes
  module CapacityRouting
    # Groups candidates into clusters based on distance-from-home gaps.
    class Clusterer
      # TODO: Make this configurable if clustering proves too coarse or too fine.
      GAP_THRESHOLD_KM = 10.0

      def initialize(company:, candidates:)
        @company = company
        @candidates = Array(candidates)
        @distance_lookup = DistanceLookup.new(company: company)
      end

      def clusters
        return [] if candidates.empty?
        return [ candidates ] unless home_base

        sorted = candidates.sort_by { |candidate| -distance_from_home(candidate).to_f }
        clusters = []
        current = []
        last_distance = nil

        sorted.each do |candidate|
          distance = distance_from_home(candidate)
          if last_distance && (last_distance - distance).abs > GAP_THRESHOLD_KM
            clusters << current if current.any?
            current = []
          end

          current << candidate
          last_distance = distance
        end

        clusters << current if current.any?
        clusters
      end

      private

      attr_reader :company, :candidates, :distance_lookup

      def home_base
        company.home_base
      end

      def distance_from_home(candidate)
        distance_lookup.distance_km(from: home_base, to: candidate.location)
      end
    end
  end
end
