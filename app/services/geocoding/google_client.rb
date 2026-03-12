# frozen_string_literal: true

require 'net/http'
require 'json'

module Geocoding
  class GoogleClient
    GEOCODE_ENDPOINT = URI('https://maps.googleapis.com/maps/api/geocode/json')
    PLACES_AUTOCOMPLETE_ENDPOINT = URI('https://places.googleapis.com/v1/places:autocomplete')
    PLACES_DETAILS_BASE = 'https://places.googleapis.com/v1/places/'

    def initialize(api_key: GoogleMaps.server_api_key)
      @api_key = api_key
    end

    def geocode(address)
      return if api_key.blank? || address.blank?

      body = request_json(GEOCODE_ENDPOINT, params: { address:, key: api_key })
      return unless body&.dig('status') == 'OK'

      location = body.dig('results', 0, 'geometry', 'location')
      return unless location

      { lat: location['lat'], lng: location['lng'] }
    end

    def autocomplete(query)
      return [] if api_key.blank? || query.blank?

      headers = google_headers(content_type: 'application/json')
      options = GoogleMaps.autocomplete_options
      payload = {
        input: query,
        languageCode: options[:language_code] || 'en',
        regionCode: options[:region_code] || 'US'
      }
      primary_types = options[:included_primary_types]
      if primary_types.present?
        payload[:includedPrimaryTypes] = Array(primary_types)
      else
        payload[:includedPrimaryTypes] = [ 'street_address' ]
      end
      if (restriction = build_location_restriction(options[:location_restriction]))
        payload[:locationRestriction] = restriction
      end
      if (bias = build_location_bias(options[:location_bias]))
        payload[:locationBias] = bias
      end

      log_debug('Places autocomplete payload', payload: short_payload(payload))

      body = request_json(
        PLACES_AUTOCOMPLETE_ENDPOINT,
        method: :post,
        headers:,
        body: payload.to_json
      )
      log_debug('Places autocomplete response', summary: response_summary(body))
      return [] unless body

      predictions = extract_predictions(body)

      predictions.map do |prediction|
        description = prediction.dig('text', 'text') ||
                      build_description_from_structured_format(prediction['structuredFormat'])
        place_id = prediction['placeId']
        next if description.blank? || place_id.blank?

        {
          description: description,
          place_id: place_id
        }
      end.compact
    end

    def place_details(place_id)
      return if api_key.blank? || place_id.blank?

      headers = google_headers
      body = request_json(
        places_details_uri(place_id),
        method: :get,
        headers:,
        params: {
          languageCode: GoogleMaps.autocomplete_options[:language_code] || 'en',
          fields: 'addressComponents,location'
        }
      )
      log_debug('Places details response', place_id: place_id, present: body.present?)
      return unless body

      components = parse_components(body['addressComponents'])
      geometry = body['location'] || {}

      {
        street: components[:street],
        city: components[:city],
        state: components[:state],
        postal_code: components[:postal_code],
        lat: geometry['latitude'],
        lng: geometry['longitude']
      }
    end

    private

    attr_reader :api_key

    def request_json(endpoint, method: :get, params: {}, headers: {}, body: nil)
      uri = endpoint.dup
      uri.query = URI.encode_www_form(params) if params.present?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      if http.use_ssl?
        http.verify_mode = GoogleMaps.verify_ssl? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end

      request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      headers.each { |key, value| request[key] = value }
      request.body = body if body

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        log_debug('Google request failed', status: response.code, body: response.body&.slice(0, 500))
        return
      end

      JSON.parse(response.body)
    rescue JSON::ParserError, StandardError => e
      log_debug('Google request exception', error: e.class.name, message: e.message)
      nil
    end

    def google_headers(content_type: nil)
      headers = { 'X-Goog-Api-Key' => api_key }
      headers['Content-Type'] = content_type if content_type.present?
      headers
    end

    def places_details_uri(place_id)
      URI("#{PLACES_DETAILS_BASE}#{place_id}")
    end

    def parse_components(components)
      map = {}
      Array(components).each do |component|
        Array(component['types']).each do |type|
          map[type] = component
        end
      end

      street_number = component_value(map['street_number'])
      route = component_value(map['route'])

      street = [ street_number, route ].compact.join(' ').strip
      street = nil if street.blank?

      {
        street: street,
        city: component_value(map['locality']) || component_value(map['postal_town']),
        state: component_short_value(map['administrative_area_level_1']),
        postal_code: component_value(map['postal_code'])
      }
    end

    def component_value(component)
      component&.dig('longText') || component&.dig('long_name') || component&.dig('text') || component&.dig('name')
    end

    def component_short_value(component)
      component&.dig('shortText') || component&.dig('short_name') || component_value(component)
    end

    def build_location_restriction(config)
      return if config.blank?
      rectangle = config[:rectangle]
      return if rectangle.blank?

      low = rectangle[:low]
      high = rectangle[:high]
      return if low.blank? || high.blank?

      {
        rectangle: {
          low: {
            latitude: low[:latitude] || low[:lat],
            longitude: low[:longitude] || low[:lng]
          },
          high: {
            latitude: high[:latitude] || high[:lat],
            longitude: high[:longitude] || high[:lng]
          }
        }
      }
    end

    def build_location_bias(config)
      return if config.blank?
      circle = config[:circle]
      return if circle.blank?

      center = circle[:center] || {}
      radius = circle[:radius]
      return if center.blank? || radius.blank?

      {
        circle: {
          center: {
            latitude: center[:latitude] || center[:lat],
            longitude: center[:longitude] || center[:lng]
          },
          radius: radius
        }
      }
    end

    def log_debug(message, data = {})
      return unless defined?(Rails)

      Rails.logger.debug("[GoogleClient] #{message}: #{data.inspect}")
    end

    def extract_predictions(body)
      entries = Array(body['placePredictions'])
      if entries.blank? && body['suggestions']
        entries = Array(body['suggestions'])
      end

      entries.map do |entry|
        entry['placePrediction'] || entry['prediction'] || entry
      end.compact
    end

    def build_description_from_structured_format(structured)
      return if structured.blank?

      main = structured.dig('mainText', 'text')
      secondary = structured.dig('secondaryText', 'text')
      [ main, secondary ].compact.join(', ')
    end

    def short_payload(payload)
      payload.merge(input: payload[:input].truncate(40))
    end

    def response_summary(body)
      return { present: false } if body.blank?

      {
        predictions: extract_predictions(body).size,
        keys: body.keys
      }
    end
  end
end
