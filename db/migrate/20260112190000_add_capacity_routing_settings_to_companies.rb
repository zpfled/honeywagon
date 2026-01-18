class AddCapacityRoutingSettingsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :routing_horizon_days, :integer, default: 3, null: false
    add_column :companies, :dump_threshold_percent, :integer, default: 90, null: false
  end
end
