class AddEstimatedDriveDistanceToRoutes < ActiveRecord::Migration[8.1]
  def change
    add_column :routes, :estimated_drive_meters, :integer
  end
end
