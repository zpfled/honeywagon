module PriceableLineItem
  extend ActiveSupport::Concern

  included do
    belongs_to :rate_plan, optional: true

    validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
    validates :subtotal_cents, numericality: { greater_than_or_equal_to: 0 }
  end

  def unit_price
    (unit_price_cents.to_i / 100.0)
  end

  def subtotal
    (subtotal_cents.to_i / 100.0)
  end
end
