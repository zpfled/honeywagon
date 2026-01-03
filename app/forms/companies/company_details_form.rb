module Companies
  class CompanyDetailsForm
    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.blank?

      company.update!(params)
    end

    private

    attr_reader :company, :params
  end
end
