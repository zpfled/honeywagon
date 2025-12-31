class CustomersController < ApplicationController
  def new
    # TODO: View reads:
    # - @customer (form model)
    # TODO: Changes needed:
    # - None.
    @customer = current_user.company.customers.new
    render layout: false if turbo_frame_request?
  end

  def create
    # TODO: View reads (on failure render :new):
    # - @customer (form model with errors)
    # TODO: Changes needed:
    # - None.
    @customer = current_user.company.customers.new(customer_params)

    respond_to do |format|
      if @customer.save
        format.turbo_stream
        format.html { redirect_to new_order_path(customer_id: @customer.id), notice: 'Customer created.' }
      else
        format.turbo_stream { render :new, status: :unprocessable_content }
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  private

  def customer_params
    params.require(:customer).permit(:business_name, :first_name, :last_name, :billing_email, :phone)
  end
end
