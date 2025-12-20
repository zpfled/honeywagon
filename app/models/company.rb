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

  validates :name, presence: true

  def inventory
    Company::Inventory.new(company: self)
  end
end
