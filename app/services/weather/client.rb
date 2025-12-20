require 'net/http'
require 'json'
require 'openssl'

module Weather
  # Thin wrapper over the National Weather Service API.
  class Client
    POINTS_ENDPOINT = 'https://api.weather.gov/points/%<lat>.4f,%<lon>.4f'.freeze
    USER_AGENT = 'Dumpr (support@dumpr.app)'.freeze

    def initialize(latitude:, longitude:)
      @latitude = latitude
      @longitude = longitude
    end

    def forecast_for(date)
      return unless (periods = forecast_periods)

      target_periods = periods.select { |period| period_date(period) == date }
      target_periods = [ nearest_period(periods, date) ].compact if target_periods.empty?
      return if target_periods.empty?

      daytime = target_periods.find { |period| period['isDaytime'] }
      nighttime = target_periods.reject { |period| period['isDaytime'] }.first

      {
        summary: (daytime || target_periods.first)['shortForecast'],
        high_temp: daytime&.[]('temperature') || target_periods.map { |p| p['temperature'] }.compact.max,
        low_temp: nighttime&.[]('temperature') || target_periods.map { |p| p['temperature'] }.compact.min,
        precip_percent: target_periods.map { |period| period.dig('probabilityOfPrecipitation', 'value') }.compact.max,
        icon_url: (daytime || target_periods.first)['icon']
      }
    rescue StandardError => e
      Rails.logger.warn("Weather forecast parsing failed: #{e.class} #{e.message}")
      nil
    end

    private

    attr_reader :latitude, :longitude

    def forecast_periods
      url = Rails.cache.fetch(points_cache_key, expires_in: 7.days) do
        points_url = format(POINTS_ENDPOINT, lat: latitude, lon: longitude)
        response = http_get(points_url)
        return unless response.is_a?(Net::HTTPSuccess)

        json = JSON.parse(response.body)
        json.dig('properties', 'forecast')
      end
      return unless url

      response = http_get(url)
      return unless response.is_a?(Net::HTTPSuccess)

      json = JSON.parse(response.body)
      json.dig('properties', 'periods')
    end

    def http_get(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      if http.use_ssl?
        http.verify_mode = Weather.verify_ssl? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end

      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/geo+json'
      request['User-Agent'] = USER_AGENT
      http.request(request)
    end

    def period_date(period)
      Time.zone.parse(period['startTime']).to_date
    end

    def nearest_period(periods, date)
      periods.min_by { |period| (period_date(period) - date).abs }
    end

    def points_cache_key
      "weather-gridpoint-#{latitude}-#{longitude}"
    end
  end
end
