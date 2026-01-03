module Companies
  class ProfileUpdater
    Result = Struct.new(:success?, :error, :error_record, keyword_init: true)

    def initialize(company:, company_params:, truck_params:, trailer_params:, customer_params:, unit_type_params:,
                   rate_plan_params:, dump_site_params:, expense_params:, unit_inventory_params:)
      @company = company
      @company_params = company_params
      @truck_params = truck_params
      @trailer_params = trailer_params
      @customer_params = customer_params
      @unit_type_params = unit_type_params
      @rate_plan_params = rate_plan_params
      @dump_site_params = dump_site_params
      @expense_params = expense_params
      @unit_inventory_params = unit_inventory_params
    end

    def call
      ActiveRecord::Base.transaction do
        forms.each(&:call)
      end

      Result.new(success?: true)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: e, error_record: e.record)
    end

    private

    attr_reader :company, :company_params, :truck_params, :trailer_params, :customer_params, :unit_type_params,
                :rate_plan_params, :dump_site_params, :expense_params, :unit_inventory_params

    def forms
      @forms ||= [
        Companies::CompanyDetailsForm.new(company: company, params: company_params),
        Companies::TruckForm.new(company: company, params: truck_params),
        Companies::TrailerForm.new(company: company, params: trailer_params),
        Companies::CustomerForm.new(company: company, params: customer_params),
        Companies::UnitTypeForm.new(company: company, params: unit_type_params),
        Companies::RatePlanForm.new(company: company, params: rate_plan_params),
        Companies::DumpSiteForm.new(company: company, params: dump_site_params),
        Companies::ExpenseForm.new(company: company, params: expense_params),
        Companies::UnitInventoryForm.new(company: company, params: unit_inventory_params)
      ]
    end
  end
end
