module Companies
  class RatePlanRowsPresenter
    def initialize(unit_types:, service_rate_plans:)
      @unit_types = unit_types
      @service_rate_plans = service_rate_plans
    end

    def rows
      unit_rows = unit_types.flat_map { |unit_type| unit_type.rate_plans.map { |plan| [ unit_type, plan ] } }
      service_rows = service_rate_plans.map { |plan| [ nil, plan ] }
      unit_rows + service_rows
    end

    private

    attr_reader :unit_types, :service_rate_plans
  end
end
