class CreateServiceEventUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :service_event_units, id: :uuid do |t|
      t.references :service_event, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :unit_type, null: false, type: :uuid, foreign_key: true
      t.integer :quantity, null: false

      t.timestamps
    end

    add_index :service_event_units, [ :service_event_id, :unit_type_id ], unique: true
  end
end
