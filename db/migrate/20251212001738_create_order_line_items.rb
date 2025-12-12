class CreateOrderLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_line_items, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :unit_type, null: false, foreign_key: true, type: :uuid
      t.references :rate_plan, null: false, foreign_key: true, type: :uuid
      t.string :service_schedule
      t.string :billing_period
      t.integer :quantity, null: false, default: 0
      t.integer :unit_price_cents, null: false, default: 0
      t.integer :subtotal_cents, null: false, default: 0

      t.timestamps
    end
  end
end
