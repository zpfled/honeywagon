module Companies
  class TruckForm
    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.values.all?(&:blank?)

      company.trucks.create!(params)
    end

    private

    attr_reader :company, :params
  end
end
