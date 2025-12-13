class CustomersController < ApplicationController
  def new
    @customer = Customer.new
    render layout: false if turbo_frame_request?
  end

  def create
    @customer = Customer.new(customer_params)

    respond_to do |format|
      if @customer.save
        format.turbo_stream
        format.html { redirect_to new_order_path(customer_id: @customer.id), notice: 'Customer created.' }
      else
        format.turbo_stream { render :new, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def customer_params
    params.require(:customer).permit(:company_name, :first_name, :last_name, :billing_email, :phone)
  end
end
