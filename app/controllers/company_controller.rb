class CompanyController < ApplicationController
  before_action :set_company

  def edit
    build_forms
    load_company_data
  end

  def update
    redirect_target = params[:redirect_to].presence
    result = Companies::ProfileUpdater.new(
      company: @company,
      company_params: company_params,
      truck_params: truck_params,
      trailer_params: trailer_params,
      customer_params: customer_params,
      unit_type_params: unit_type_params,
      rate_plan_params: rate_plan_params,
      dump_site_params: dump_site_params,
      expense_params: expense_params,
      unit_inventory_params: unit_inventory_params
    ).call

    if result.success?
      redirect_to(redirect_target || edit_company_path, notice: 'Company profile updated.')
      return
    end

    error_record = result.error_record
    flash.now[:alert] =
      if error_record.present?
        error_record.errors.full_messages.to_sentence
      else
        'Unable to update company profile.'
      end

    template =
      case redirect_target
      when customers_company_path then :customers
      when expenses_company_path then :expenses
      else :edit
      end

    case template
    when :customers
      load_customers_page_data
    when :expenses
      load_expenses_page_data
    else
      load_company_data
    end
    build_forms
    render template, status: :unprocessable_content
  end

  def customers
    build_forms
    load_customers_page_data
  end

  def expenses
    build_forms
    load_expenses_page_data
  end

  private

  def set_company
    @company = Company.find(current_user.company_id)
  end

  def load_company_data
    @unit_types = @company.unit_types.includes(:rate_plans).order(:name)
    @unit_counts_by_type = @company.units.group(:unit_type_id).count
    service_rate_plans = @company.rate_plans.service_only.order(:service_schedule)
    @rate_plan_rows = Companies::RatePlanRowsPresenter.new(
      unit_types: @unit_types,
      service_rate_plans: service_rate_plans
    ).rows
    @trucks = @company.trucks.where.not(id: nil).order(:name).to_a
    @trailers = @company.trailers.where.not(id: nil).order(:name).to_a
    @dump_sites = @company.dump_sites.includes(:location).where.not(id: nil).order(:name).to_a
    @customers = @company.customers.where.not(id: nil).order(:display_name).to_a
    @expenses = @company.expenses.where.not(id: nil).order(:name).to_a
    @service_schedule_options = RatePlan::SERVICE_SCHEDULES.values.map { |value| [ value.humanize, value ] }
    @billing_period_options = RatePlan::BILLING_PERIODS.map { |period| [ period.humanize, period ] }
    @expense_category_options = Expense::CATEGORIES.map { |value| [ value.humanize, value ] }
    @expense_type_options = Expense::COST_TYPES.map { |value| [ value.humanize, value ] }
    @expense_applies_options = Expense::APPLIES_TO_OPTIONS.map { |value| [ value.humanize, value ] }
  end

  def load_customers_page_data
    @customers = @company.customers.order(:display_name)
  end

  def load_expenses_page_data
    @expenses = @company.expenses.order(:name)
    @expense_category_options = Expense::CATEGORIES.map { |value| [ value.humanize, value ] }
    @expense_type_options = Expense::COST_TYPES.map { |value| [ value.humanize, value ] }
    @expense_applies_options = Expense::APPLIES_TO_OPTIONS.map { |value| [ value.humanize, value ] }
  end

  def company_params
    params.fetch(:company, {}).permit(
      :name,
      :fuel_price_per_gallon,
      home_base_attributes: %i[id label street city state zip lat lng]
    )
  end

  def truck_params
    params.fetch(:truck, {}).permit(:name, :number, :clean_water_capacity_gal, :waste_capacity_gal, :fuel_price_per_gallon, :miles_per_gallon)
  end

  def trailer_params
    params.fetch(:trailer, {}).permit(:name, :identifier, :capacity_spots)
  end

  def customer_params
    params.fetch(:customer, {}).permit(:business_name, :first_name, :last_name, :billing_email, :phone)
  end

  def unit_type_params
    params.fetch(:unit_type, {}).permit(
      :name,
      :slug,
      :prefix,
      :delivery_clean_gallons,
      :service_clean_gallons,
      :service_waste_gallons,
      :pickup_clean_gallons,
      :pickup_waste_gallons
    )
  end

  def unit_inventory_params
    params.fetch(:unit_inventory, {}).permit(:unit_type_id, :quantity)
  end

  def rate_plan_params
    params.fetch(:rate_plan, {}).permit(:unit_type_id, :service_schedule, :billing_period, :price_cents, :effective_on, :expires_on, :active)
  end

  def dump_site_params
    params.fetch(:dump_site, {}).permit(:name, location_attributes: %i[label street city state zip])
  end

  def expense_params
    params.fetch(:expense, {}).permit(
      :name,
      :description,
      :category,
      :cost_type,
      :base_amount,
      :package_size,
      :unit_label,
      :season_start,
      :season_end,
      :active,
      applies_to: []
    )
  end

  def new_unit_type
    @unit_type = @company.unit_types.new
    render partial: 'company/unit_type_modal', layout: false
  end

  def new_rate_plan
    @rate_plan = @company.rate_plans.new
    locals = {
      company: @company,
      service_schedule_options: @service_schedule_options || RatePlan::SERVICE_SCHEDULES.values.map { |value| [ value.humanize, value ] },
      billing_period_options: @billing_period_options || RatePlan::BILLING_PERIODS.map { |period| [ period.humanize, period ] }
    }
    render partial: 'company/rate_plan_modal', locals: locals, layout: false
  end

  def new_trailer
    @trailer = @company.trailers.new
    render partial: 'company/trailer_modal', layout: false
  end

  def new_customer
    @customer = @company.customers.new
    render partial: 'company/customer_modal', layout: false
  end

  def new_expense
    @expense = @company.expenses.new
    locals = {
      expense_category_options: @expense_category_options || Expense::CATEGORIES.map { |value| [ value.humanize, value ] },
      expense_type_options: @expense_type_options || Expense::COST_TYPES.map { |value| [ value.humanize, value ] },
      expense_applies_options: @expense_applies_options || Expense::APPLIES_TO_OPTIONS.map { |value| [ value.humanize, value ] }
    }
    render partial: 'company/expense_modal', locals: locals, layout: false
  end

  def build_forms
    @truck ||= @company.trucks.new
    @trailer ||= @company.trailers.new
    @customer ||= @company.customers.new
    @unit_type ||= @company.unit_types.new
    @rate_plan ||= @company.rate_plans.new
    @dump_site ||= @company.dump_sites.new.tap { |site| site.build_location }
    @expense ||= @company.expenses.new
    @company.build_home_base unless @company.home_base
  end
end
