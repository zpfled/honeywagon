module Companies
  class RatePlanForm
    include FormNormalizers

    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.values.all?(&:blank?)

      attrs = params.dup
      unit_type_id = attrs.delete(:unit_type_id).presence
      attrs[:price_cents] = normalize_price(attrs[:price_cents])
      attrs[:active] = attrs.key?(:active) ? ActiveModel::Type::Boolean.new.cast(attrs[:active]) : true

      if unit_type_id.present?
        unit_type = company.unit_types.find(unit_type_id)
        rate_plan = unit_type.rate_plans.new(attrs.compact)
      else
        rate_plan = company.rate_plans.new(attrs.compact)
      end

      rate_plan.company = company
      rate_plan.save!
    end

    private

    attr_reader :company, :params
  end
end
