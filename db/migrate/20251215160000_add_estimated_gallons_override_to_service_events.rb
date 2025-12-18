class AddEstimatedGallonsOverrideToServiceEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :service_events, :estimated_gallons_override, :integer
  end
end
