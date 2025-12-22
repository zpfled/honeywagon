class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :description
      t.string :category, null: false
      t.string :cost_type, null: false
      t.decimal :base_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :package_size, precision: 12, scale: 3
      t.string :unit_label
      t.string :applies_to, array: true, default: []
      t.date :season_start
      t.date :season_end
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :expenses, %i[company_id category]
    add_index :expenses, :applies_to, using: :gin
  end
end
