class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders, id: :uuid do |t|
      t.references :customer, null: false, foreign_key: true, type: :uuid
      t.references :location, null: false, foreign_key: true, type: :uuid
      t.string :external_reference
      t.string :status
      t.date :start_date
      t.date :end_date
      t.integer :rental_subtotal_cents
      t.integer :delivery_fee_cents
      t.integer :pickup_fee_cents
      t.integer :discount_cents
      t.integer :tax_cents
      t.integer :total_cents
      t.text :notes

      t.timestamps
    end
  end
end
