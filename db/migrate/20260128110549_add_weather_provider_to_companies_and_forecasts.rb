class AddWeatherProviderToCompaniesAndForecasts < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :weather_provider, :string, null: false, default: 'nws'
    add_column :weather_forecasts, :provider, :string, null: false, default: 'nws'
    add_index :weather_forecasts, [ :company_id, :provider, :forecast_date, :latitude, :longitude ], name: 'idx_weather_forecasts_provider'
  end
end
