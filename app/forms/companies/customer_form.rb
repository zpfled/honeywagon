module Companies
  class CustomerForm
    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.values.all?(&:blank?)

      company.customers.create!(params)
    end

    private

    attr_reader :company, :params
  end
end
