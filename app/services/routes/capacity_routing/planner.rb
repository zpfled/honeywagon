module Routes
  module CapacityRouting
    # Orchestrates capacity-aware route planning using clustering + greedy ordering.
    class Planner
      Result = Struct.new(:routes, :errors, keyword_init: true)

      def initialize(company:, start_date: Date.current, horizon_days: nil)
        @company = company
        @start_date = start_date
        @horizon_days = horizon_days || company.routing_horizon_days || 3
      end

      def self.call(company:, start_date: Date.yesterday, horizon_days: nil)
        new(company: company, start_date: start_date, horizon_days: horizon_days).call
      end

    def call
      candidates = CandidatePool.new(company: company, start_date: start_date, horizon_days: horizon_days).events
      return Result.new(routes: [], errors: []) if candidates.empty?

      clusters = Clusterer.new(company: company, candidates: candidates).clusters
      routes = clusters.flat_map do |cluster|
        RouteBuilder.new(company: company, start_date: start_date, candidates: cluster).routes
      end

      Result.new(routes: routes, errors: [])
    end

      private

      attr_reader :company, :start_date, :horizon_days
    end
  end
end
