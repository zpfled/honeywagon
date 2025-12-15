class LocationsController < ApplicationController
  before_action :load_customers

  def new
    @location = Location.new(customer_id: params[:customer_id])
    render layout: false if turbo_frame_request?
  end

  def create
    @location = Location.new(location_params.except(:customer_id))
    assign_customer!

    if @location.errors[:customer].present?
      respond_to do |format|
        format.turbo_stream { render :new, status: :unprocessable_content }
        format.html { render :new, status: :unprocessable_content }
      end
      return
    end

    respond_to do |format|
      if @location.save
        format.turbo_stream
        format.html do
          redirect_to new_order_path(customer_id: @location.customer_id, location_id: @location.id),
                      notice: 'Location created.'
        end
      else
        format.turbo_stream { render :new, status: :unprocessable_content }
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  private

  def load_customers
    @customers = current_user.company.customers.order(:display_name)
  end

  def assign_customer!
    customer_id = location_params[:customer_id]
    if customer_id.blank?
      @location.errors.add(:customer, 'must be selected')
      return
    end

    @location.customer = @customers.find(customer_id)
  rescue ActiveRecord::RecordNotFound
    @location.errors.add(:customer, 'must belong to your company')
  end

  def location_params
    params.require(:location).permit(:customer_id, :label, :street, :city, :state, :zip, :access_notes, :lat, :lng)
  end
end
