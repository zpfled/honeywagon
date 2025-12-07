class AddPrefixToUnitTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_types, :prefix, :string
  end
end
