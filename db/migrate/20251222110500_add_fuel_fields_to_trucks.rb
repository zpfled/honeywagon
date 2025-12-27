class AddFuelFieldsToTrucks < ActiveRecord::Migration[8.1]
  def change
    add_column :trucks, :miles_per_gallon, :decimal, precision: 6, scale: 2
  end
end
