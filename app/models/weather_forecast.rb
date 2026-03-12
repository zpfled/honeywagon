# WeatherForecast caches daily forecasts for a company/date/provider.
class WeatherForecast < ApplicationRecord
  belongs_to :company

  validates :forecast_date, presence: true
  validates :retrieved_at, presence: true
  validates :provider, presence: true
end
