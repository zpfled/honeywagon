class CreateServiceEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :service_events, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.date :scheduled_on
      t.integer :event_type
      t.integer :status
      t.text :notes

      t.timestamps
    end
  end
end
