module Routes
  module Generation
    class RunResolver
      Result = Struct.new(:run, :status, keyword_init: true)

      def self.call(company:, scope:, run_id: nil, allow_cross_scope_run_id: false)
        new(
          company: company,
          scope: scope,
          run_id: run_id,
          allow_cross_scope_run_id: allow_cross_scope_run_id
        ).call
      end

      def initialize(company:, scope:, run_id:, allow_cross_scope_run_id:)
        @company = company
        @scope = scope
        @run_id = run_id
        @allow_cross_scope_run_id = allow_cross_scope_run_id
      end

      def call
        found = find_by_id
        return Result.new(run: found, status: :found) if found

        run = company.route_generation_runs.active_for(company: company, scope_key: scope.scope_key).first
        run ||= company.route_generation_runs.where(scope_key: scope.scope_key).order(created_at: :desc).first
        status = run.present? ? :found : :missing

        Result.new(run: run, status: status)
      end

      private

      attr_reader :company, :scope, :run_id, :allow_cross_scope_run_id

      def find_by_id
        return nil if run_id.blank?

        if allow_cross_scope_run_id
          company.route_generation_runs.find_by(id: run_id)
        else
          company.route_generation_runs.find_by(id: run_id, scope_key: scope.scope_key)
        end
      end
    end
  end
end
