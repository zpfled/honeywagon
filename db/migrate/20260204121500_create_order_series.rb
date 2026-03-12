class CreateOrderSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :order_series, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :company_id, null: false
      t.uuid :created_by_id
      t.string :name, null: false
      t.text :notes

      t.timestamps
    end

    add_index :order_series, :company_id
    add_index :order_series, :created_by_id
  end
end
