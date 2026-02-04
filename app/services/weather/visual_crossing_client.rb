require 'net/http'
require 'json'
require 'openssl'

module Weather
  # Thin wrapper over the Visual Crossing API.
  class VisualCrossingClient
    USER_AGENT = 'Dumpr (support@dumpr.app)'.freeze

    def initialize(latitude:, longitude:, api_key: VisualCrossing.api_key)
      @latitude = latitude
      @longitude = longitude
      @api_key = api_key
    end

    def forecast_for(date)
      return if api_key.blank?

      days = daily_forecasts
      return if days.blank?

      target = days.find { |entry| entry['datetime'] == date.to_s }
      return unless target

      {
        summary: target['description'] || target['conditions'],
        high_temp: target['tempmax'],
        low_temp: target['tempmin'],
        precip_percent: target['precipprob'],
        icon_url: nil
      }
    rescue StandardError => e
      Rails.logger.warn(
        message: 'Visual Crossing forecast parsing failed',
        error_class: e.class.name,
        error_message: e.message,
        latitude: latitude,
        longitude: longitude
      )
      nil
    end

    private

    attr_reader :latitude, :longitude, :api_key

    def daily_forecasts
      response = http_get("#{VisualCrossing.base_url}/timeline/#{formatted_coords}", unitGroup: 'us', include: 'days')
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn(
          message: 'Visual Crossing forecast request failed',
          status: response&.code,
          body: response&.body&.slice(0, 200),
          latitude: latitude,
          longitude: longitude
        )
        return
      end

      json = JSON.parse(response.body)
      json['days']
    end

    def http_get(url, params = {})
      uri = URI(url)
      query = params.merge(key: api_key)
      uri.query = URI.encode_www_form(query)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      if http.use_ssl?
        http.verify_mode = VisualCrossing.verify_ssl? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end

      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/json'
      request['User-Agent'] = USER_AGENT
      http.request(request)
    end

    def formatted_coords
      format('%.4f,%.4f', latitude.to_f, longitude.to_f)
    end
  end
end
