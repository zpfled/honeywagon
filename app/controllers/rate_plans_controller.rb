# frozen_string_literal: true

class RatePlansController < ApplicationController
  include FormNormalizers
  before_action :load_unit_types

  def new
    # TODO: View reads:
    # - @rate_plan (form model)
    # - @unit_type (header + hidden field)
    # TODO: Changes needed:
    # - None.
    @unit_type = find_unit_type
    return render_missing_unit_type unless @unit_type

    @rate_plan = RatePlan.new(unit_type: @unit_type, company: @unit_type.company, active: true)
    render layout: false if turbo_frame_request?
  end

  def create
    # TODO: View reads (on failure render :new):
    # - @rate_plan (form model with errors)
    # - @unit_type (header + hidden field)
    # TODO: Changes needed:
    # - None.
    @rate_plan = RatePlan.new(rate_plan_params)
    @unit_type = find_unit_type(@rate_plan.unit_type_id)

    return render_missing_unit_type if @unit_type.nil?

    @rate_plan.company = @unit_type.company

    if @rate_plan.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to new_order_path, notice: 'Rate plan created.' }
      end
    else
      render_new_with_error
    end
  end

  private

  def load_unit_types
    @unit_types = current_user.company.unit_types.order(:name)
  end

  def find_unit_type(id = params[:unit_type_id])
    return if id.blank?

    @unit_types.find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def render_missing_unit_type
    respond_to do |format|
      format.turbo_stream { render plain: 'Select a unit type before adding a rate plan.', status: :unprocessable_content }
      format.html { render plain: 'Select a unit type before adding a rate plan.', status: :unprocessable_content }
    end
  end

  def render_new_with_error
    respond_to do |format|
      format.turbo_stream { render :new, status: :unprocessable_content }
      format.html { render :new, status: :unprocessable_content }
    end
  end

  def rate_plan_params
    attrs = params.require(:rate_plan).permit(:unit_type_id, :service_schedule, :billing_period, :price)
    attrs[:unit_type_id] = attrs[:unit_type_id].presence
    attrs[:price_cents] = normalize_price(attrs.delete(:price)) if attrs[:price].present?
    attrs[:active] = true
    attrs
  end
end
