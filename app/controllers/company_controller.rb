class CompanyController < ApplicationController
  include FormNormalizers
  before_action :set_company

  def edit
    # TODO: View reads:
    # - @company (profile form)
    # - @unit_types, @rate_plan_rows, @service_schedule_options, @billing_period_options
    # - @dump_sites, @trucks, @trailers
    # - @unit_type, @rate_plan, @dump_site, @truck, @trailer (inline forms/modals)
    # TODO: Changes needed:
    # - Ensure preloads cover unit_type units/counts and dump_site locations.
    # - Move any aggregation/formatting for rate_plan_rows into presenters/services if it grows.
    # - AR reads in view: app/views/company/edit.html.erb:137,144 (unit_type.units.count).
    build_forms
    load_company_data
  end

  def update
    # TODO: View reads (on error render :edit/:customers/:expenses):
    # - edit: @company, @unit_types, @rate_plan_rows, @service_schedule_options, @billing_period_options,
    #   @dump_sites, @trucks, @trailers, @unit_type, @rate_plan, @dump_site, @truck, @trailer
    # - customers: @customers, @customer
    # - expenses: @expenses, @expense_category_options, @expense_type_options, @expense_applies_options, @expense
    # TODO: Changes needed:
    # - Extract the create/update workflow into services/form objects to slim controller (already TODO).
    # - Keep view aggregation in presenters/services as it expands.
    # - AR reads in view: app/views/company/edit.html.erb:137,144 (unit_type.units.count).
    redirect_target = params[:redirect_to].presence
    ActiveRecord::Base.transaction do
      # TODO: extract these create/update steps into dedicated services/form objects to slim the controller
      update_company_details!
      create_truck!
      create_trailer!
      create_customer!
      create_unit_type!
      create_rate_plan!
      create_dump_site!
      create_expense!
      update_unit_inventory!
    end

    redirect_to(redirect_target || edit_company_path, notice: 'Company profile updated.')
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
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
    # TODO: View reads:
    # - @customers (list)
    # - @customer (inline form model)
    # TODO: Changes needed:
    # - None.
    build_forms
    load_customers_page_data
  end

  def expenses
    # TODO: View reads:
    # - @expenses (list)
    # - @expense_category_options, @expense_type_options, @expense_applies_options (form selects)
    # - @expense (inline form model)
    # TODO: Changes needed:
    # - None.
    build_forms
    load_expenses_page_data
  end

  private

  def set_company
    @company = Company.find(current_user.company_id)
  end

  def load_company_data
    @unit_types = @company.unit_types.includes(:units, :rate_plans).order(:name)
    @unit_counts_by_type = @company.units.group(:unit_type_id).count
    service_rows = @company.rate_plans.service_only.order(:service_schedule).map { |plan| [ nil, plan ] }
    @rate_plan_rows = @unit_types.flat_map { |ut| ut.rate_plans.map { |plan| [ ut, plan ] } } + service_rows
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
    params.fetch(:unit_type, {}).permit(:name, :slug, :prefix)
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

  def update_company_details!
    attrs = company_params
    return if attrs.blank?

    @company.update!(attrs)
  end

  def create_truck!
    attrs = truck_params
    return if attrs.values.all?(&:blank?)

    @company.trucks.create!(attrs)
  end

  def create_trailer!
    attrs = trailer_params
    return if attrs.values.all?(&:blank?)

    @company.trailers.create!(attrs)
  end

  def create_customer!
    attrs = customer_params
    return if attrs.values.all?(&:blank?)

    @company.customers.create!(attrs)
  end

  def create_unit_type!
    attrs = unit_type_params
    return if attrs.values.all?(&:blank?)

    attrs[:slug] = attrs[:name].to_s.parameterize.presence || attrs[:slug]
    attrs[:prefix] = attrs[:prefix].to_s.upcase if attrs[:prefix].present?
    attrs[:next_serial] = 1

    @unit_type = @company.unit_types.new(attrs.compact)
    @unit_type.save!
  end

  def create_rate_plan!
    attrs = rate_plan_params
    return if attrs.values.all?(&:blank?)

    unit_type_id = attrs.delete(:unit_type_id).presence
    attrs[:price_cents] = normalize_price(attrs[:price_cents])
    attrs[:active] = attrs.key?(:active) ? ActiveModel::Type::Boolean.new.cast(attrs[:active]) : true

    if unit_type_id.present?
      unit_type = @company.unit_types.find(unit_type_id)
      @rate_plan = unit_type.rate_plans.new(attrs.compact)
    else
      @rate_plan = @company.rate_plans.new(attrs.compact)
    end

    @rate_plan.company = @company
    @rate_plan.save!
  end

  def create_dump_site!
    attrs = dump_site_params
    return if attrs.blank?

    location_attrs = attrs.delete(:location_attributes) || {}
    location = Location.new(location_attrs)
    location.dump_site = true
    location.save!

    @dump_site = @company.dump_sites.new(attrs.merge(location: location))
    @dump_site.save!
  end

  def create_expense!
    attrs = expense_params
    return if attrs.blank? || attrs[:name].blank?

    attrs[:base_amount] = normalize_decimal(attrs[:base_amount])
    attrs[:package_size] = normalize_decimal(attrs[:package_size])
    attrs[:active] = attrs.key?(:active) ? ActiveModel::Type::Boolean.new.cast(attrs[:active]) : true
    attrs[:applies_to] = Array(attrs[:applies_to]).reject(&:blank?)

    @expense = @company.expenses.new(attrs.compact)
    @expense.save!
  end

  def update_unit_inventory!
    attrs = unit_inventory_params
    return if attrs.blank? || attrs[:unit_type_id].blank? || attrs[:quantity].blank?

    unit_type = @company.unit_types.find(attrs[:unit_type_id])
    target = attrs[:quantity].to_i
    raise ActiveRecord::RecordInvalid.new(unit_type), 'Quantity must be zero or greater.' if target.negative?

    current = unit_type.units.count
    difference = target - current
    return if difference.zero?

    if difference.positive?
      difference.times { @company.units.create!(unit_type: unit_type, status: 'available') }
    else
      removable = unit_type.units.where(status: 'available').order(created_at: :desc)
      needed = difference.abs
      if removable.count < needed
        unit_type.errors.add(:base, "Only #{removable.count} available units can be removed right now.")
        raise ActiveRecord::RecordInvalid.new(unit_type)
      end
      removable.limit(needed).each(&:destroy!)
    end
  end

  # normalize helpers now provided by FormNormalizers concern
end
