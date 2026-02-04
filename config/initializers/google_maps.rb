module GoogleMaps
  module_function

  def api_key
    Rails.application.credentials.dig(:google_maps, :api_key) ||
      ENV['GOOGLE_MAPS_API_KEY'] ||
      config['api_key']
  end

  def server_api_key
    Rails.application.credentials.dig(:google_maps, :server_api_key) ||
      ENV['GOOGLE_MAPS_SERVER_API_KEY'] ||
      config['server_api_key'] ||
      api_key
  end

  def verify_ssl?
    value = Rails.application.credentials.dig(:google_maps, :verify_ssl)
    value = ENV['GOOGLE_MAPS_VERIFY_SSL'] if value.nil?
    value = config['verify_ssl'] if value.nil?
    value = true if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def autocomplete_options
    @autocomplete_options ||= begin
      raw = config['autocomplete'] || {}
      raw.deep_symbolize_keys
    end
  end

  def config
    @config ||= Rails.application.config_for(:google_maps)
  end
end
