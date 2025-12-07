class AddManufacturerToUnits < ActiveRecord::Migration[8.1]
  def up
    add_column :units, :manufacturer, :string

    GenericUnits.find_each do |unit|
      unit.update(manufacturer: "unknown")
    end

    change_column_null :units, :manufacturer, false
  end

  def down
    remove_column :units, :manufacturer
  end

  class GenericUnits < ApplicationRecord
    self.table_name = "units"
  end
end
