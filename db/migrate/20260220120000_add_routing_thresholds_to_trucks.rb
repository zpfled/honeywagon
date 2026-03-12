class AddRoutingThresholdsToTrucks < ActiveRecord::Migration[8.1]
  def change
    add_column :trucks, :waste_yellow_threshold_pct, :integer
    add_column :trucks, :waste_red_threshold_pct, :integer
    add_column :trucks, :waste_red_nearby_miles, :decimal, precision: 5, scale: 2
    add_column :trucks, :waste_early_dump_proximity_miles, :decimal, precision: 5, scale: 2

    add_column :trucks, :water_yellow_threshold_pct, :integer
    add_column :trucks, :water_red_threshold_pct, :integer
    add_column :trucks, :water_red_nearby_miles, :decimal, precision: 5, scale: 2
    add_column :trucks, :water_early_refill_proximity_miles, :decimal, precision: 5, scale: 2
    add_column :trucks, :water_min_reserve_gal, :integer
  end
end
