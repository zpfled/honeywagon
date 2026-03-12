module AccuWeather
  module_function

  def api_key
    Rails.application.credentials.dig(:accuweather, :api_key) ||
      ENV['ACCUWEATHER_API_KEY'] ||
      config['api_key']
  end

  def base_url
    config['base_url'] || 'https://dataservice.accuweather.com'
  end

  def verify_ssl?
    value = Rails.application.credentials.dig(:accuweather, :verify_ssl)
    value = ENV['ACCUWEATHER_VERIFY_SSL'] if value.nil?
    value = config['verify_ssl'] if value.nil?
    value = true if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def config
    @config ||= Rails.application.config_for(:accuweather)
  end
end
