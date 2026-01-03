module Companies
  class TrailerForm
    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.values.all?(&:blank?)

      company.trailers.create!(params)
    end

    private

    attr_reader :company, :params
  end
end
