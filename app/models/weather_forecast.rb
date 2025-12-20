# WeatherForecast caches the National Weather Service forecast for a company/date.
class WeatherForecast < ApplicationRecord
  belongs_to :company

  validates :forecast_date, presence: true
  validates :retrieved_at, presence: true
end
