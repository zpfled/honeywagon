class OrdersController < ApplicationController
  before_action :set_order, only: %i[show edit update destroy]

  def index
    @orders = Order.includes(:customer, :location).order(start_date: :desc)
  end

  def show
    @order_presenter = OrderPresenter.new(@order, view_context: view_context)
  end

  def new
    @order = Order.new(
      start_date: Date.today,
      end_date:   Date.today + 7.days,
      status:     'draft'
    )
  end

  def create
    builder = Orders::Builder.new(Order.new)
    @order  = builder.assign(
      params:               order_params,
      unit_type_requests: unit_type_requests_params
    )
    if @order.errors.empty? && @order.save
      redirect_to @order, notice: 'Order created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    builder = Orders::Builder.new(@order)
    builder.assign(
      params:               order_params,
      unit_type_requests: unit_type_requests_params
    )

    if @order.errors.empty? && @order.save
      redirect_to @order, notice: 'Order updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @order.destroy
    redirect_to orders_path, notice: 'Order deleted.'
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def order_params
    params.require(:order).permit(
      :customer_id,
      :location_id,
      :external_reference,
      :status,
      :start_date,
      :end_date,
      :notes,
      :rental_subtotal_cents,
      :delivery_fee_cents,
      :pickup_fee_cents,
      :discount_cents,
      :tax_cents,
      :total_cents
    )
  end

  def unit_type_requests_params
    raw = params.dig(:order, :unit_type_requests) || {}

    raw.transform_values do |h|
      {
        quantity: h[:quantity].to_i,
        service_schedule: h[:service_schedule].to_s
      }
    end
  end
end
