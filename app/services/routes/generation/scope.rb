module Routes
  module Generation
    class Scope
      attr_reader :company, :strategy

      def initialize(company:, scope_start:, scope_end:, strategy: 'capacity_v1')
        @company = company
        @scope_start = scope_start
        @scope_end = scope_end
        @strategy = strategy
      end

      def scope_key
        @scope_key ||= [
          'calendar',
          'v1',
          company.id,
          window_start.iso8601,
          window_end.iso8601,
          strategy
        ].join(':')
      end

      def window_start
        @scope_start.to_date
      end

      def window_end
        @scope_end.to_date
      end
    end
  end
end
