class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations, id: :uuid do |t|
      t.references :customer, null: true, foreign_key: true, type: :uuid
      t.string :label
      t.string :street
      t.string :city
      t.string :state
      t.string :zip
      t.decimal :lat
      t.decimal :lng
      t.text :access_notes
      t.boolean :dump_site

      t.timestamps
    end

    add_index :locations, :dump_site
  end
end
