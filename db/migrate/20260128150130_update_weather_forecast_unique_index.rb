class UpdateWeatherForecastUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :weather_forecasts, name: 'index_weather_forecasts_on_company_date_and_location', if_exists: true
    add_index :weather_forecasts, [ :company_id, :provider, :forecast_date, :latitude, :longitude ], unique: true, name: 'idx_weather_forecasts_provider', if_not_exists: true
  end
end
