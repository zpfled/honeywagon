class RenameOrdersUserReference < ActiveRecord::Migration[7.0]
  def up
    remove_foreign_key :orders, :users
    rename_index :orders, 'index_orders_on_user_id', 'index_orders_on_created_by_id'
    rename_column :orders, :user_id, :created_by_id
    change_column_null :orders, :created_by_id, true
    add_foreign_key :orders, :users, column: :created_by_id
  end

  def down
    remove_foreign_key :orders, column: :created_by_id
    change_column_null :orders, :created_by_id, false
    rename_index :orders, 'index_orders_on_created_by_id', 'index_orders_on_user_id'
    rename_column :orders, :created_by_id, :user_id
    add_foreign_key :orders, :users
  end
end
