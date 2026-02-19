# frozen_string_literal: true

module Api
  class PlacesController < ApplicationController
    before_action :authenticate_user!

    def autocomplete
      query = params[:query].to_s
      suggestions = google_client.autocomplete(query)
      Rails.logger.info("[Places] autocomplete query=#{query} suggestions=#{suggestions.size}")
      if query.present? && suggestions.empty?
        Rails.logger.warn("[Places] autocomplete returned zero suggestions query=#{query}")
      end
      render json: { suggestions: suggestions }
    end

    def details
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
