class DashboardController < ApplicationController
  def index
    @service_events = current_user.service_events.upcoming_week.includes(order: [ :customer, :location ])
    @inventory_stats = inventory_stats
    @ytd_order_total_cents = year_to_date_order_total_cents
  end

  private

  def inventory_stats
    unit_types = UnitType.order(:name)
    totals = Unit.group(:unit_type_id).count
    status_counts = Unit.group(:unit_type_id, :status).count
    monthly_counts = monthly_rental_counts
    event_counts = event_rental_counts

    unit_types.map do |unit_type|
      {
        unit_type: unit_type,
        total_units: totals[unit_type.id] || 0,
        available_units: status_counts[[ unit_type.id, 'available' ]] || 0,
        rented_units: status_counts[[ unit_type.id, 'rented' ]] || 0,
        monthly_out: monthly_counts[unit_type.id] || 0,
        event_out: event_counts[unit_type.id] || 0
      }
    end
  end

  def monthly_rental_counts
    OrderLineItem
      .joins(:order)
      .where(orders: { status: %w[scheduled active] })
      .where(billing_period: 'monthly')
      .group(:unit_type_id)
      .sum(:quantity)
  end

  def event_rental_counts
    OrderLineItem
      .joins(:order)
      .where(orders: { status: %w[scheduled active] })
      .where(billing_period: 'per_event')
      .group(:unit_type_id)
      .sum(:quantity)
  end

  def year_to_date_order_total_cents
    start_of_year = Date.current.beginning_of_year
    end_of_year = Date.current.end_of_year

    Order
      .where(start_date: start_of_year..end_of_year)
      .sum(:total_cents)
      .to_i
  end
end
