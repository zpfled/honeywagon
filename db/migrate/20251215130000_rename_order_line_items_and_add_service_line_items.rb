class RenameOrderLineItemsAndAddServiceLineItems < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :order_line_items, :orders
    remove_foreign_key :order_line_items, :rate_plans
    remove_foreign_key :order_line_items, :unit_types

    rename_table :order_line_items, :rental_line_items

    add_foreign_key :rental_line_items, :orders
    add_foreign_key :rental_line_items, :rate_plans
    add_foreign_key :rental_line_items, :unit_types

    create_table :service_line_items, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.string :description, null: false
      t.string :service_schedule, null: false, default: 'none'
      t.integer :units_serviced, null: false, default: 1
      t.timestamps
    end
  end

  def down
    drop_table :service_line_items

    remove_foreign_key :rental_line_items, :orders
    remove_foreign_key :rental_line_items, :rate_plans
    remove_foreign_key :rental_line_items, :unit_types

    rename_table :rental_line_items, :order_line_items

    add_foreign_key :order_line_items, :orders
    add_foreign_key :order_line_items, :rate_plans
    add_foreign_key :order_line_items, :unit_types
  end
end
