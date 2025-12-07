class CreateUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :units, id: :uuid do |t|
      t.references :unit_type, null: false, foreign_key: true, type: :uuid
      t.string :serial
      t.string :status

      t.timestamps
    end

    add_index :units, :status
  end
end
