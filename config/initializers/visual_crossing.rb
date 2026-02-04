module VisualCrossing
  module_function

  def api_key
    Rails.application.credentials.dig(:visual_crossing, :api_key) ||
      ENV['VISUAL_CROSSING_API_KEY'] ||
      config['api_key']
  end

  def base_url
    config['base_url'] || 'https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services'
  end

  def verify_ssl?
    value = Rails.application.credentials.dig(:visual_crossing, :verify_ssl)
    value = ENV['VISUAL_CROSSING_VERIFY_SSL'] if value.nil?
    value = config['verify_ssl'] if value.nil?
    value = true if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def config
    @config ||= Rails.application.config_for(:visual_crossing)
  rescue Errno::ENOENT, RuntimeError
    {}
  end
end
