# Company represents a single tenant that owns users, units, and orders.
class Company < ApplicationRecord
  WEATHER_PROVIDERS = {
    nws: 'NWS (weather.gov)',
    accuweather: 'AccuWeather',
    visual_crossing: 'Visual Crossing'
  }.freeze

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
  has_many :order_series, dependent: :destroy
  has_many :rate_plans, dependent: :destroy
  has_many :dump_sites, dependent: :destroy
  has_many :weather_forecasts, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :tasks, dependent: :destroy
  belongs_to :home_base, class_name: 'Location', optional: true

  validates :name, presence: true
  validates :routing_horizon_days, numericality: { greater_than: 0 }, allow_nil: true
  validates :dump_threshold_percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :weather_provider, inclusion: { in: WEATHER_PROVIDERS.keys.map(&:to_s) }
  accepts_nested_attributes_for :home_base

  after_update_commit :trigger_weather_refresh, if: :saved_change_to_weather_provider?

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

  private

  def trigger_weather_refresh
    update_column(:forecast_refresh_at, nil)
    Weather::ForecastRefreshJob.perform_later(id)
  end
end
