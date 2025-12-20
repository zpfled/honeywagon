class RenameSeptageColumnsToWaste < ActiveRecord::Migration[8.1]
  def change
    rename_column :trucks, :septage_capacity_gal, :waste_capacity_gal
    rename_column :trucks, :septage_load_gal, :waste_load_gal
  end
end
