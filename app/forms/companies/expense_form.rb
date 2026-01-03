module Companies
  class ExpenseForm
    include FormNormalizers

    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.blank? || params[:name].blank?

      attrs = params.dup
      attrs[:base_amount] = normalize_decimal(attrs[:base_amount])
      attrs[:package_size] = normalize_decimal(attrs[:package_size])
      attrs[:active] = attrs.key?(:active) ? ActiveModel::Type::Boolean.new.cast(attrs[:active]) : true
      attrs[:applies_to] = Array(attrs[:applies_to]).reject(&:blank?)

      company.expenses.create!(attrs.compact)
    end

    private

    attr_reader :company, :params
  end
end
