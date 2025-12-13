class CreateServiceEventReports < ActiveRecord::Migration[8.1]
  def change
    create_table :service_event_reports, id: :uuid do |t|
      t.references :service_event, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end
  end
end
