module Weather
  class ForecastRefreshJob < ApplicationJob
    queue_as :default

    def perform(company_id)
      company = Company.find_by(id: company_id)
      return unless company

      location = company.home_base
      return unless location&.lat.present? && location&.lng.present?

      start_date = Date.current
      end_date = start_date + Weather::ForecastFetcher.forecast_horizon(company)

      start_date.upto(end_date) do |date|
        Weather::ForecastFetcher.call(
          company: company,
          date: date,
          latitude: location.lat,
          longitude: location.lng
        )
      end

      company.update_column(:forecast_refresh_at, Time.current)
    end
  end
end
