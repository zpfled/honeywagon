class CreateServiceEventTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :service_event_types, id: :uuid do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :requires_report, null: false, default: false
      t.jsonb :report_fields, null: false, default: []

      t.timestamps
    end

    add_index :service_event_types, :key, unique: true

    add_reference :service_events, :service_event_type, type: :uuid, foreign_key: true
  end
end
