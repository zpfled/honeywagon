class AddEstimatedDriveTimeToRoutes < ActiveRecord::Migration[8.1]
  def change
    add_column :routes, :estimated_drive_seconds, :integer
    add_column :routes, :optimization_stale, :boolean, default: true, null: false
  end
end
