module Weather
  # Retrieves and caches an NWS forecast for a company on a specific date.
  class ForecastFetcher
    CACHE_WINDOW = 12.hours
    FORECAST_HORIZON = 10.days

    def self.call(company:, date:, latitude:, longitude:)
      return unless date.present? && latitude.present? && longitude.present?
      return if date > Date.current + FORECAST_HORIZON

      new(company: company, date: date, latitude: latitude, longitude: longitude).call
    end

    def initialize(company:, date:, latitude:, longitude:)
      @company = company
      @date = date
      @latitude = latitude.to_f.round(4)
      @longitude = longitude.to_f.round(4)
    end

    def call
      cached = cached_forecast
      return cached if cached&.retrieved_at.present? && cached.retrieved_at > CACHE_WINDOW.ago

      data = client.forecast_for(date)
      return cached if data.nil?

      forecast = cached || company.weather_forecasts.new(forecast_date: date, latitude: latitude, longitude: longitude)
      forecast.assign_attributes(
        summary: data[:summary],
        high_temp: data[:high_temp],
        low_temp: data[:low_temp],
        precip_percent: data[:precip_percent],
        icon_url: data[:icon_url],
        retrieved_at: Time.current
      )
      forecast.save!
      forecast
    rescue StandardError => e
      Rails.logger.warn(
        message: 'Weather forecast fetch failed',
        error_class: e.class.name,
        error_message: e.message,
        company_id: company.id,
        forecast_date: date,
        latitude: latitude,
        longitude: longitude
      )
      cached
    end

    private

    attr_reader :company, :date, :latitude, :longitude

    def cached_forecast
      @cached_forecast ||= company.weather_forecasts.find_by(
        forecast_date: date,
        latitude: latitude,
        longitude: longitude
      )
    end

    def client
      @client ||= Weather::Client.new(latitude: latitude, longitude: longitude)
    end
  end
end
