module Companies
  class UnitTypeForm
    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.values.all?(&:blank?)

      attrs = params.dup
      attrs[:slug] = attrs[:name].to_s.parameterize.presence || attrs[:slug]
      attrs[:prefix] = attrs[:prefix].to_s.upcase if attrs[:prefix].present?
      attrs[:next_serial] = 1

      company.unit_types.create!(attrs.compact)
    end

    private

    attr_reader :company, :params
  end
end
