class AddOrderSeriesToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :order_series_id, :uuid
    add_column :orders, :suppress_recurring_service_events, :boolean, default: false, null: false
    add_index :orders, :order_series_id
  end
end
