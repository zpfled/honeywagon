class CreateTrucksAndTrailers < ActiveRecord::Migration[8.1]
  def change
    create_table :trucks, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :number, null: false
      t.integer :clean_water_capacity_gal, null: false, default: 0
      t.integer :septage_capacity_gal, null: false, default: 0
      t.timestamps
    end

    add_index :trucks, [ :company_id, :number ], unique: true

    create_table :trailers, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :identifier, null: false
      t.integer :capacity_spots, null: false, default: 0
      t.timestamps
    end

    add_index :trailers, [ :company_id, :identifier ], unique: true

    change_table :routes, bulk: true do |t|
      t.references :truck, null: true, foreign_key: { to_table: :trucks }, type: :uuid
      t.references :trailer, null: true, foreign_key: { to_table: :trailers }, type: :uuid
    end
  end
end
