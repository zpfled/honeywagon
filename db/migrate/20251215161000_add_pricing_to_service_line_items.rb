class AddPricingToServiceLineItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :service_line_items,
                  :rate_plan,
                  type: :uuid,
                  foreign_key: true,
                  index: true,
                  null: true

    add_column :service_line_items, :unit_price_cents, :integer, null: false, default: 0
    add_column :service_line_items, :subtotal_cents, :integer, null: false, default: 0
  end
end
