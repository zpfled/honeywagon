module Routes
  module Optimization
    # High-level coordinator invoked by controllers/UI. Calls the optimizer
    # and returns a normalized payload for the view layer.
    class Run
      Result = Struct.new(:success?, :event_ids_in_order, :warnings, :errors, :simulation, keyword_init: true)

      def initialize(route)
        @route = route
      end

      def self.call(route)
        new(route).call
      end

      def call
        optimization = Routes::Optimization::GoogleOptimizer.call(route)
        Result.new(
          success?: optimization.errors.empty?,
          event_ids_in_order: optimization.event_ids_in_order,
          warnings: optimization.warnings,
          errors: optimization.errors,
          simulation: optimization.simulation
        )
      end

      private

      attr_reader :route
    end
  end
end
