class CompanyController < ApplicationController
  def edit
    @company = current_user.company
    build_forms
  end

  def update
    @company = current_user.company

    ActiveRecord::Base.transaction do
      update_company_details!
      create_truck!
      create_trailer!
      create_customer!
      create_unit_type!
      create_rate_plan!
      create_dump_site!
      update_unit_inventory!
    end

    redirect_to edit_company_path, notice: 'Company profile updated.'
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    build_forms
    render :edit, status: :unprocessable_content
  end

  private

  def company_params
    params.fetch(:company, {}).permit(:name)
  end

  def truck_params
    params.fetch(:truck, {}).permit(:name, :number, :clean_water_capacity_gal, :septage_capacity_gal)
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

  def build_forms
    @truck ||= current_user.company.trucks.new
    @trailer ||= current_user.company.trailers.new
    @customer ||= current_user.company.customers.new
    @unit_type ||= current_user.company.unit_types.new
    @rate_plan ||= current_user.company.rate_plans.new
    @dump_site ||= current_user.company.dump_sites.new.tap { |site| site.build_location }
  end

  def update_company_details!
    attrs = company_params
    return if attrs.blank?

    @company.update!(attrs)
  end

  def create_truck!
    attrs = truck_params
    return if attrs.values.all?(&:blank?)

    current_user.company.trucks.create!(attrs)
  end

  def create_trailer!
    attrs = trailer_params
    return if attrs.values.all?(&:blank?)

    current_user.company.trailers.create!(attrs)
  end

  def create_customer!
    attrs = customer_params
    return if attrs.values.all?(&:blank?)

    current_user.company.customers.create!(attrs)
  end

  def create_unit_type!
    attrs = unit_type_params
    return if attrs.values.all?(&:blank?)

    attrs[:slug] = attrs[:name].to_s.parameterize.presence || attrs[:slug]
    attrs[:prefix] = attrs[:prefix].to_s.upcase if attrs[:prefix].present?
    attrs[:next_serial] = 1

    @unit_type = current_user.company.unit_types.new(attrs.compact)
    @unit_type.save!
  end

  def create_rate_plan!
    attrs = rate_plan_params
    return if attrs.values.all?(&:blank?)

    unit_type_id = attrs.delete(:unit_type_id).presence
    attrs[:price_cents] = normalize_price(attrs[:price_cents])
    attrs[:active] = attrs.key?(:active) ? ActiveModel::Type::Boolean.new.cast(attrs[:active]) : true

    if unit_type_id.present?
      unit_type = current_user.company.unit_types.find(unit_type_id)
      @rate_plan = unit_type.rate_plans.new(attrs.compact)
    else
      @rate_plan = current_user.company.rate_plans.new(attrs.compact)
    end

    @rate_plan.company = current_user.company
    @rate_plan.save!
  end

  def create_dump_site!
    attrs = dump_site_params
    return if attrs.blank?

    location_attrs = attrs.delete(:location_attributes) || {}
    location = Location.new(location_attrs)
    location.dump_site = true
    location.save!

    @dump_site = current_user.company.dump_sites.new(attrs.merge(location: location))
    @dump_site.save!
  end

  def update_unit_inventory!
    attrs = unit_inventory_params
    return if attrs.blank? || attrs[:unit_type_id].blank? || attrs[:quantity].blank?

    unit_type = current_user.company.unit_types.find(attrs[:unit_type_id])
    target = attrs[:quantity].to_i
    raise ActiveRecord::RecordInvalid.new(unit_type), 'Quantity must be zero or greater.' if target.negative?

    current = unit_type.units.count
    difference = target - current
    return if difference.zero?

    if difference.positive?
      difference.times do
        current_user.company.units.create!(unit_type: unit_type, status: 'available')
      end
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

  def normalize_price(value)
    return if value.blank?

    (BigDecimal(value.to_s) * 100).to_i
  rescue ArgumentError, TypeError
    nil
  end
end
