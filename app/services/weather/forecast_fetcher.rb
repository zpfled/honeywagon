module Weather
  # Retrieves and caches an NWS forecast for a company on a specific date.
  class ForecastFetcher
    CACHE_WINDOW = 12.hours
    FORECAST_HORIZON = 10.days

    def self.call(company:, date:, latitude:, longitude:)
      return unless date.present? && latitude.present? && longitude.present?
      return if date > Date.current + forecast_horizon(company)

      new(company: company, date: date, latitude: latitude, longitude: longitude).call
    end

    def initialize(company:, date:, latitude:, longitude:)
      @company = company
      @date = date
      @latitude = latitude.to_f.round(4)
      @longitude = longitude.to_f.round(4)
      @provider = company.weather_provider.presence || 'nws'
    end

    def call
      cached = cached_forecast
      return cached if cached&.retrieved_at.present? && cached.retrieved_at > CACHE_WINDOW.ago

      data = client.forecast_for(date)
      return cached if data.nil?

      forecast = cached || company.weather_forecasts.new(forecast_date: date, latitude: latitude, longitude: longitude, provider: provider)
      forecast.assign_attributes(
        summary: data[:summary],
        high_temp: data[:high_temp],
        low_temp: data[:low_temp],
        precip_percent: data[:precip_percent],
        icon_url: data[:icon_url],
        retrieved_at: Time.current
      )
      forecast.save!
      log_forecast(forecast)
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

    attr_reader :company, :date, :latitude, :longitude, :provider

    def cached_forecast
      @cached_forecast ||= company.weather_forecasts.find_by(
        provider: provider,
        forecast_date: date,
        latitude: latitude,
        longitude: longitude
      )
    end

    def client
      @client ||= case provider
                  when 'accuweather'
                    Weather::AccuWeatherClient.new(latitude: latitude, longitude: longitude)
                  when 'visual_crossing'
                    Weather::VisualCrossingClient.new(latitude: latitude, longitude: longitude)
                  else
                    Weather::Client.new(latitude: latitude, longitude: longitude)
                  end
    end

    def self.forecast_horizon(company)
      provider = company.weather_provider.presence || 'nws'
      return 5.days if provider == 'accuweather'
      return 15.days if provider == 'visual_crossing'

      FORECAST_HORIZON
    end

    def log_forecast(forecast)
      log = ForecastLog.find_or_initialize_by(
        company_id: company.id,
        provider: provider,
        forecast_date: date,
        latitude: latitude,
        longitude: longitude
      )

      log.predicted_high_temp = forecast.high_temp
      log.predicted_low_temp = forecast.low_temp
      log.predicted_precip_percent = forecast.precip_percent
      log.retrieved_at = forecast.retrieved_at

      if date == Date.current
        log.observed_high_temp ||= forecast.high_temp
        log.observed_low_temp ||= forecast.low_temp
      end

      log.save!
    rescue StandardError => e
      Rails.logger.warn(
        message: 'Forecast log write failed',
        error_class: e.class.name,
        error_message: e.message,
        company_id: company.id,
        forecast_date: date,
        provider: 'nws'
      )
    end
  end
end
