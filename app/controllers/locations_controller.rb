class LocationsController < ApplicationController
  before_action :set_customer_scope

  def new
    @customer = find_customer_from_params
    return render_missing_customer unless @customer

    @location = Location.new(customer: @customer)
    render layout: false if turbo_frame_request?
  end

  def create
    place_id = location_params[:place_id]
    @location = Location.new(location_params.except(:customer_id, :place_id))
    assign_customer!
    apply_place_details(place_id)

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

  def set_customer_scope
    @customer_scope = current_user.company.customers
  end

  def find_customer_from_params
    return if params[:customer_id].blank?

    @customer_scope.find(params[:customer_id])
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def render_missing_customer
    respond_to do |format|
      format.turbo_stream { render plain: 'Select a customer before adding a location.', status: :unprocessable_content }
      format.html { render plain: 'Select a customer before adding a location.', status: :unprocessable_content }
    end
  end

  def assign_customer!
    customer_id = location_params[:customer_id]
    if customer_id.blank?
      @location.errors.add(:customer, 'must be selected')
      return
    end

    @location.customer = @customer_scope.find(customer_id)
  rescue ActiveRecord::RecordNotFound
    @location.errors.add(:customer, 'must belong to your company')
  end

  def location_params
    params.require(:location).permit(:customer_id, :label, :street, :city, :state, :zip, :access_notes, :lat, :lng, :place_id)
  end

  def apply_place_details(place_id)
    return if place_id.blank?

    details = Geocoding::GoogleClient.new.place_details(place_id)
    return if details.blank?

    @location.lat = details[:lat] if details[:lat]
    @location.lng = details[:lng] if details[:lng]
    @location.street = details[:street] if @location.street.blank? && details[:street]
    @location.city = details[:city] if @location.city.blank? && details[:city]
    @location.state = details[:state] if @location.state.blank? && details[:state]
    @location.zip = details[:postal_code] if @location.zip.blank? && details[:postal_code]
  end
end
