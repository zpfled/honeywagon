class CreateWeatherForecasts < ActiveRecord::Migration[8.1]
  def change
    create_table :weather_forecasts, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.date :forecast_date, null: false
      t.decimal :latitude, precision: 8, scale: 4
      t.decimal :longitude, precision: 9, scale: 4
      t.string :summary
      t.integer :high_temp
      t.integer :low_temp
      t.integer :precip_percent
      t.string :icon_url
      t.datetime :retrieved_at, null: false

      t.timestamps
    end

    add_index :weather_forecasts,
              %i[company_id forecast_date latitude longitude],
              unique: true,
              name: 'index_weather_forecasts_on_company_date_and_location'
  end
end
