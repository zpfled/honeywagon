class OrdersController < ApplicationController
  before_action :set_order, only: %i[show edit update destroy schedule]

  def index
    @orders = current_user.orders.includes(:customer, :location).order(start_date: :desc)
  end

  def show
    @order_presenter = OrderPresenter.new(@order, view_context: view_context)
  end

  def new
    @order = current_user.orders.new(
      start_date: Date.today,
      end_date:   Date.today + 7.days,
      status:     'draft',
      customer_id: params[:customer_id]
    )
  end

  def create
    @order = current_user.orders.new
    builder = Orders::Builder.new(@order)
    builder.assign(
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

  def schedule
    @order.schedule!
    redirect_to @order, notice: 'Order scheduled.'
  rescue StandardError => e
    redirect_to @order, alert: "Unable to schedule order: #{e.message}"
  end

  private

  def set_order
    @order = current_user.orders.find(params[:id])
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
    raw = params.dig(:order, :unit_type_requests)
    return [] unless raw.present?

    entries =
      if raw.is_a?(Array)
        raw
      else
        raw.respond_to?(:values) ? raw.values : Array(raw)
      end

    entries.map do |entry|
      source =
        if entry.respond_to?(:to_unsafe_h)
          entry.to_unsafe_h
        elsif entry.respond_to?(:to_h)
          entry.to_h
        else
          entry
        end

      attrs = source.respond_to?(:with_indifferent_access) ? source.with_indifferent_access : source

      {
        unit_type_id: attrs[:unit_type_id],
        rate_plan_id: attrs[:rate_plan_id],
        quantity: attrs[:quantity].to_i
      }
    end
  end
end
