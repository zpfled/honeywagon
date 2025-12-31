# frozen_string_literal: true

module Api
  class PlacesController < ApplicationController
    before_action :authenticate_user!

    def autocomplete
      # TODO: View reads:
      # - JSON response with suggestions list.
      # TODO: Changes needed:
      # - None.
      suggestions = google_client.autocomplete(params[:query].to_s)
      Rails.logger.info("[Places] autocomplete query=#{params[:query]} suggestions=#{suggestions.size}")
      render json: { suggestions: suggestions }
    end

    def details
      # TODO: View reads:
      # - JSON response with place details.
      # TODO: Changes needed:
      # - None.
      Rails.logger.debug("[Places] details request place_id=#{params[:place_id]}")
      details = google_client.place_details(params[:place_id].to_s)
      if details.present?
        Rails.logger.info("[Places] details place_id=#{params[:place_id]} resolved=1 lat=#{details[:lat]} lng=#{details[:lng]}")
        render json: details
      else
        Rails.logger.warn("[Places] details place_id=#{params[:place_id]} returned no data")
        head :unprocessable_content
      end
    end

    private

    def google_client
      @google_client ||= Geocoding::GoogleClient.new
    end
  end
end
