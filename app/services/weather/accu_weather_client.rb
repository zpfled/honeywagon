require 'net/http'
require 'json'
require 'openssl'

module Weather
  # Thin wrapper over the AccuWeather API.
  class AccuWeatherClient
    USER_AGENT = 'Dumpr (support@dumpr.app)'.freeze

    def initialize(latitude:, longitude:, api_key: AccuWeather.api_key)
      @latitude = latitude
      @longitude = longitude
      @api_key = api_key
    end

    def forecast_for(date)
      return if api_key.blank?

      key = location_key
      return if key.blank?

      daily = daily_forecasts
      return if daily.blank?

      target = daily.find { |entry| forecast_date(entry) == date }
      return unless target

      day = target['Day'] || {}
      night = target['Night'] || {}
      temps = target['Temperature'] || {}

      {
        summary: day['IconPhrase'] || night['IconPhrase'],
        high_temp: temps.dig('Maximum', 'Value'),
        low_temp: temps.dig('Minimum', 'Value'),
        precip_percent: max_precip(day, night),
        icon_url: nil
      }
    rescue StandardError => e
      Rails.logger.warn(
        message: 'AccuWeather forecast parsing failed',
        error_class: e.class.name,
        error_message: e.message,
        latitude: latitude,
        longitude: longitude
      )
      nil
    end

    private

    attr_reader :latitude, :longitude, :api_key

    def location_key
      Rails.cache.fetch(location_cache_key, expires_in: 7.days) do
        response = http_get("#{AccuWeather.base_url}/locations/v1/cities/geoposition/search", q: formatted_coords)
        return unless response.is_a?(Net::HTTPSuccess)

        json = JSON.parse(response.body)
        json['Key']
      end
    end

    def daily_forecasts
      response = http_get("#{AccuWeather.base_url}/forecasts/v1/daily/5day/#{location_key}", details: true, metric: false)
      return unless response.is_a?(Net::HTTPSuccess)

      json = JSON.parse(response.body)
      json['DailyForecasts']
    end

    def http_get(url, params = {})
      uri = URI(url)
      query = params.merge(apikey: api_key)
      uri.query = URI.encode_www_form(query)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      if http.use_ssl?
        http.verify_mode = AccuWeather.verify_ssl? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end

      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/json'
      request['User-Agent'] = USER_AGENT
      http.request(request)
    end

    def formatted_coords
      format('%.4f,%.4f', latitude.to_f, longitude.to_f)
    end

    def forecast_date(entry)
      Time.zone.parse(entry['Date']).to_date
    end

    def max_precip(day, night)
      [
        day['PrecipitationProbability'],
        night['PrecipitationProbability'],
        day['RainProbability'],
        night['RainProbability'],
        day['SnowProbability'],
        night['SnowProbability']
      ].compact.max
    end

    def location_cache_key
      "accuweather-location-#{formatted_coords}"
    end
  end
end
