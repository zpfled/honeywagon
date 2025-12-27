class AddDriveMetricsToServiceEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :service_events, :drive_distance_meters, :integer, null: false, default: 0
    add_column :service_events, :drive_duration_seconds, :integer, null: false, default: 0
  end
end
