# RentalLineItem captures the pricing snapshot for each unit type on an order.
class RentalLineItem < ApplicationRecord
  include PriceableLineItem

  belongs_to :order
  belongs_to :unit_type

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :service_schedule, :billing_period, presence: true
end
