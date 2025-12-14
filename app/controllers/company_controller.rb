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

  def build_forms
    @truck = current_user.company.trucks.new
    @trailer = current_user.company.trailers.new
    @customer = Customer.new
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
end
