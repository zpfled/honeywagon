# OrderUnit links a specific unit to an order for a concrete date range.
class OrderUnit < ApplicationRecord
  belongs_to :order
  belongs_to :unit

  validates :billing_period, presence: true, inclusion: { in: RatePlan::BILLING_PERIODS }
  validates :placed_on, presence: true
  validate  :removed_on_after_placed_on, if: -> { removed_on.present? }
  validate :unit_available_for_order_dates

  # Returns the number of days the unit stays on the order for pricing logic.
  def rental_days
    return 0 if placed_on.blank?

    (effective_removed_on - placed_on).to_i + 1
  end

  private

  # Determines the removal date to use (explicit date, order end date, or start).
  def effective_removed_on
    removed_on || order&.end_date || placed_on
  end

  # Ensures the removal date cannot precede the placed_on date.
  def removed_on_after_placed_on
    if removed_on < placed_on
      errors.add(:removed_on, 'must be on or after placed_on')
    end
  end

  # Validates that the linked unit is not already booked for the date range.
  def unit_available_for_order_dates
    return if order.blank? || unit.blank?
    return if order.start_date.blank? || order.end_date.blank?

    overlapping_blocking_orders = unit.orders
      .where(status: Order::BLOCKING_STATUSES) # e.g. scheduled, active
      .where.not(id: order.id)                 # ignore this same order
      .where('start_date <= ? AND end_date >= ?', order.end_date, order.start_date)

    if overlapping_blocking_orders.exists?
      errors.add(:base, 'Unit is already booked for that date range')
    end
  end
end
