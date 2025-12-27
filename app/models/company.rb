# Company represents a single tenant that owns users, units, and orders.
class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :unit_types, dependent: :destroy
  has_many :units, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :routes, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :locations, through: :customers
  has_many :trucks, dependent: :destroy
  has_many :trailers, dependent: :destroy
  has_many :service_events, through: :orders
  has_many :rate_plans, dependent: :destroy
  has_many :dump_sites, dependent: :destroy
  has_many :weather_forecasts, dependent: :destroy
  has_many :expenses, dependent: :destroy
  belongs_to :home_base, class_name: 'Location', optional: true

  validates :name, presence: true
  accepts_nested_attributes_for :home_base

  def inventory
    Company::Inventory.new(company: self)
  end

  # TODO: replace usages with a money presenter, since we'll only want to do calculations on cents and present it
  # as a decimal to end users
  def fuel_price_per_gallon
    return nil if fuel_price_per_gal_cents.blank?

    fuel_price_per_gal_cents / 100.0
  end

  # TODO: if value is blank, return 0
  # TODO: if generalize the transformation of decimal dollars to cents in a concern or helper
  def fuel_price_per_gallon=(value)
    cents =
      if value.blank?
        nil
      else
        (BigDecimal(value.to_s) * 100).round
      end

    self.fuel_price_per_gal_cents = cents
  end
end
