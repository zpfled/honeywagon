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
      coerce_capacity_fields!(attrs)

      company.unit_types.create!(attrs.compact)
    end

    private

    attr_reader :company, :params

    def coerce_capacity_fields!(attrs)
      %i[
        delivery_clean_gallons
        service_clean_gallons
        service_waste_gallons
        pickup_clean_gallons
        pickup_waste_gallons
      ].each do |key|
        next unless attrs.key?(key)
        value = attrs[key]
        attrs[key] = value.to_s.strip.presence&.to_i
      end
    end
  end
end
