class CreateOrderUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :order_units, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :unit, null: false, foreign_key: true, type: :uuid
      t.date :placed_on
      t.date :removed_on
      t.integer :daily_rate_cents

      t.timestamps
    end
  end
end
