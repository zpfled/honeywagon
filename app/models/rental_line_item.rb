# RentalLineItem captures the pricing snapshot for each unit type on an order.
class RentalLineItem < ApplicationRecord
  belongs_to :order
  belongs_to :unit_type
  belongs_to :rate_plan, optional: true

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :service_schedule, :billing_period, presence: true
end
