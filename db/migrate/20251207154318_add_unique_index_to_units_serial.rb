class AddUniqueIndexToUnitsSerial < ActiveRecord::Migration[7.1]
  def change
    add_index :units, :serial, unique: true
  end
end
