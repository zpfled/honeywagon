# frozen_string_literal: true

module Weather
  def self.verify_ssl?
    value = Rails.application.credentials.dig(:weather, :verify_ssl)
    value = ENV['WEATHER_VERIFY_SSL'] if value.nil?
    value = config[:verify_ssl] if value.nil?
    value = true if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def self.config
    @config ||= begin
      Rails.application.config_for(:weather).with_indifferent_access
    rescue StandardError
      {}
    end
  end
end
