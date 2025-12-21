# frozen_string_literal: true

require 'net/http'
require 'json'

module Routes
  module Optimization
    class GoogleRoutesClient
      ENDPOINT = URI('https://routes.googleapis.com/directions/v2:computeRoutes')
      FIELD_MASK = 'routes.distanceMeters,routes.duration,routes.optimizedIntermediateWaypointIndex'

      Result = Struct.new(
        :success?,
        :event_ids_in_order,
        :warnings,
        :errors,
        :total_distance_meters,
        :total_duration_seconds,
        keyword_init: true
      )

      def initialize(api_key: GoogleMaps.api_key)
        @api_key = api_key
      end

      def optimize(stops)
        return failure_result([ 'Google routing API key is not configured.' ]) if api_key.blank?
        return success_result(stops.map { |s| s[:id] }, warnings: [ 'Not enough stops to optimize.' ]) if stops.size <= 1

        body = build_payload(stops)
        response = request_json(ENDPOINT, body: body)
        return failure_result([ 'Google routing request failed.' ]) unless response

        error = response['error']
        return failure_result([ error['message'] ]) if error

        route = Array(response['routes']).first
        unless route
          Rails.logger.debug("[GoogleRoutesClient] empty routes array returned: #{response.inspect.slice(0, 500)}")
          return failure_result([ 'Google routing response missing route data.' ])
        end

        waypoint_order = Array(route['optimizedIntermediateWaypointIndex'])
        event_ids = reorder_ids(stops, waypoint_order)
        distance = route['distanceMeters'].to_i
        duration = parse_duration(route['duration'])

        success_result(event_ids, warnings: [], total_distance_meters: distance, total_duration_seconds: duration)
      end

      private

      attr_reader :api_key

      def build_payload(stops)
        origin = build_waypoint(stops.first)
        destination = build_waypoint(stops.last)
        intermediates = stops[1...-1].map { |stop| build_waypoint(stop) }

        {
          origin: origin,
          destination: destination,
          intermediates: intermediates,
          travelMode: 'DRIVE',
          optimizeWaypointOrder: intermediates.present?,
          requestedReferenceRoutes: []
        }
      end

      def build_waypoint(stop)
        {
          location: {
            latLng: {
              latitude: stop[:lat].to_f,
              longitude: stop[:lng].to_f
            }
          }
        }
      end

      def reorder_ids(stops, waypoint_order)
        intermediate = stops[1...-1]
        return stops.map { |s| s[:id] } unless intermediate.present? && waypoint_order.present?

        ordered_intermediate = waypoint_order.map { |idx| intermediate[idx] }.compact
        [ stops.first, *ordered_intermediate, stops.last ].map { |stop| stop[:id] }
      end

      def parse_duration(duration_string)
        return 0 unless duration_string

        if duration_string =~ /([0-9]+)s$/
          Regexp.last_match(1).to_i
        else
          0
        end
      end

      def success_result(event_ids, warnings:, total_distance_meters:, total_duration_seconds:)
        Result.new(
          success?: true,
          event_ids_in_order: event_ids,
          warnings: warnings,
          errors: [],
          total_distance_meters: total_distance_meters,
          total_duration_seconds: total_duration_seconds
        )
      end

      def failure_result(errors)
        Result.new(success?: false, event_ids_in_order: [], warnings: [], errors: Array(errors))
      end

      def request_json(endpoint, body: {})
        uri = endpoint
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = GoogleMaps.verify_ssl? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Post.new(uri)
        request['X-Goog-Api-Key'] = api_key
        request['X-Goog-FieldMask'] = FIELD_MASK
        request['Content-Type'] = 'application/json'
        request.body = body.to_json

        Rails.logger.debug { "[GoogleRoutesClient] request payload: #{body.to_json}" }

        response = http.request(request)
        raw_body = response.body.to_s

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.debug { "[GoogleRoutesClient] request failed: status=#{response.code}, headers=#{response.each_header.to_h}, body=#{raw_body}" }
          return JSON.parse(raw_body) rescue nil
        end

        parsed = JSON.parse(raw_body)
        Rails.logger.debug { "[GoogleRoutesClient] response body: headers=#{response.each_header.to_h}, body=#{parsed.inspect}" }
        parsed
      rescue JSON::ParserError, StandardError => e
        Rails.logger.debug("[GoogleRoutesClient] request failed: #{e.class} - #{e.message}")
        nil
      end
    end
  end
end
