class ForecastLog < ApplicationRecord
  PROVIDERS = %w[nws accuweather visual_crossing].freeze

  belongs_to :company

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :forecast_date, presence: true
end
