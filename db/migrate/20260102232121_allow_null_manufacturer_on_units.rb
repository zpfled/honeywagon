class AllowNullManufacturerOnUnits < ActiveRecord::Migration[8.1]
  def change
    change_column_null :units, :manufacturer, true
  end
end
