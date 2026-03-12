module Routes
  module CapacityRouting
    # Groups candidates into proximity clusters based on nearest-neighbor
    # distances between candidates (not distance from home base).
    class Clusterer
      # TODO: Make this configurable if clustering proves too coarse or too fine.
      GAP_THRESHOLD_KM = 16.1

      # Stores inputs and a distance helper used during clustering.
      def initialize(company:, candidates:)
        @company = company
        @candidates = Array(candidates)
        @distance_lookup = DistanceLookup.new(company: company)
      end

      # Splits candidates into connected proximity groups.
      # Two candidates belong to the same cluster when there is a chain of
      # "nearby" hops between them, where each hop is <= GAP_THRESHOLD_KM.
      def clusters
        return [] if candidates.empty?

        remaining = candidates.dup
        grouped = []

        # Grow each cluster via a small graph traversal (BFS): start from one
        # unassigned candidate, then keep adding neighbors within threshold.
        while remaining.any?
          seed = remaining.shift
          component = [ seed ]
          queue = [ seed ]

          until queue.empty?
            current = queue.shift
            neighbors = neighboring_candidates(current, remaining)
            next if neighbors.empty?

            neighbors.each do |neighbor|
              remaining.delete(neighbor)
              component << neighbor
              queue << neighbor
            end
          end

          grouped << component
        end

        grouped
      end

      private

      attr_reader :company, :candidates, :distance_lookup

      # Returns unassigned candidates close enough to join the same cluster.
      # If distance is unknown (missing coordinates), we do not link them.
      def neighboring_candidates(candidate, pool)
        pool.select do |other|
          distance = distance_lookup.distance_km(from: candidate.location, to: other.location)
          distance.present? && distance <= GAP_THRESHOLD_KM
        end
      end
    end
  end
end
