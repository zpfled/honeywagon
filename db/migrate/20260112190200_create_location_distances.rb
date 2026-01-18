class CreateLocationDistances < ActiveRecord::Migration[8.1]
  def change
    create_table :location_distances, id: :uuid do |t|
      t.references :from_location, null: false, type: :uuid, foreign_key: { to_table: :locations, on_delete: :cascade }
      t.references :to_location, null: false, type: :uuid, foreign_key: { to_table: :locations, on_delete: :cascade }
      t.decimal :distance_km, precision: 10, scale: 3, null: false
      t.datetime :computed_at, null: false

      t.timestamps
    end

    add_index :location_distances, [ :from_location_id, :to_location_id ], unique: true
  end
end
