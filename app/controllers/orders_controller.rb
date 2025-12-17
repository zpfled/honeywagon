class OrdersController < ApplicationController
  before_action :set_order, only: %i[show edit update destroy schedule]
  before_action :load_form_options, only: %i[new create edit update]

  def index
    @orders = current_user.company.orders.includes(:customer, :location).order(start_date: :desc)
  end

  def show
    @order_presenter = OrderPresenter.new(@order, view_context: view_context)
    @service_event_types = ServiceEvent.event_types.keys
  end

  def new
    @order = current_user.company.orders.new(
      start_date: Date.today,
      end_date:   Date.today + 7.days,
      status:     'draft',
      customer_id: params[:customer_id],
      location_id: params[:location_id],
      created_by: current_user
    )
  end

  def create
    @order = current_user.company.orders.new(created_by: current_user)
    builder = Orders::Builder.new(@order)
    builder.assign(
      params:               order_params,
      unit_type_requests:   unit_type_requests_params,
      service_item_requests: service_line_items_params
    )
    if @order.errors.empty? && @order.save
      redirect_to @order, notice: 'Order created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    builder = Orders::Builder.new(@order)
    builder.assign(
      params:               order_params,
      unit_type_requests:   unit_type_requests_params,
      service_item_requests: service_line_items_params
    )

    if @order.errors.empty? && @order.save
      redirect_to @order, notice: 'Order updated.'
    else
      render :edit, status: :unprocessable_content
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
    @order = current_user.company.orders.find(params[:id])
  end

  def load_form_options
    @unit_types = current_user.company.unit_types.order(:name)
    @customers = current_user.company.customers.order(:display_name)
    @locations = current_user.company.locations.includes(:customer).order(:label)
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

  def service_line_items_params
    raw = params.dig(:order, :service_line_items)
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
        description: attrs[:description],
        service_schedule: attrs[:service_schedule],
        units_serviced: attrs[:units_serviced]
      }
    end
  end
end
