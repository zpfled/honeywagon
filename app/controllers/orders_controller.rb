class OrdersController < ApplicationController
  before_action :set_order, only: %i[show edit update destroy]

  # TODO: add Pundit authorize calls when you wire policies

  def index
    @orders = Order.includes(:customer, :location).order(start_date: :desc)
  end

  def show
  end

  def new
    @order = Order.new(
      start_date: Date.today,
      end_date: Date.today + 7.days,
      status: "draft"
    )
  end

  def create
    @order = Order.new(order_params)

    if @order.save
      redirect_to @order, notice: "Order created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
      if @order.update(order_params)
        redirect_to @order, notice: "Order updated."
      else
        render :edit, status: :unprocessable_entity
      end
  end

  def destroy
    @order.destroy
    redirect_to orders_path, notice: "Order deleted."
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  # Note: we're using `unit_ids` to manage the join table automatically.
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
      :total_cents,
      unit_ids: [] # <— assigns OrderUnits behind the scenes
    )
  end
end
