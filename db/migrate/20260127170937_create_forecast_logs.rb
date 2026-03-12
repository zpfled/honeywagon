class CreateForecastLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :forecast_logs, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.date :forecast_date, null: false
      t.string :provider, null: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.integer :predicted_high_temp
      t.integer :predicted_low_temp
      t.integer :predicted_precip_percent
      t.integer :observed_high_temp
      t.integer :observed_low_temp
      t.datetime :retrieved_at
      t.timestamps
    end

    add_index :forecast_logs, [ :company_id, :provider, :forecast_date, :latitude, :longitude ], unique: true, name: 'idx_forecast_logs_unique'
    add_index :forecast_logs, [ :company_id, :forecast_date ]
  end
end
