class CreateUnitTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_types, id: :uuid do |t|
      t.string :name
      t.string :slug

      t.timestamps
    end
  end
end
