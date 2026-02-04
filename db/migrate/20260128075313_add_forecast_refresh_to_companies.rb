class AddForecastRefreshToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :forecast_refresh_at, :datetime
  end
end
