class OrderUnit < ApplicationRecord
  belongs_to :order
  belongs_to :unit

  validates :placed_on, presence: true
  validate  :removed_on_after_placed_on, if: -> { removed_on.present? }
  validate :unit_available_for_order_dates

  # how many days this unit is on this order (for pricing later)
  def rental_days
    return 0 if placed_on.blank?

    (effective_removed_on - placed_on).to_i + 1
  end

  private

  def effective_removed_on
    removed_on || order&.end_date || placed_on
  end

  def removed_on_after_placed_on
    if removed_on < placed_on
      errors.add(:removed_on, 'must be on or after placed_on')
    end
  end

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
