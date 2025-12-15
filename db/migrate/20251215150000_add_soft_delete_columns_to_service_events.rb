class AddSoftDeleteColumnsToServiceEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :service_events, :deleted_at, :datetime
    add_reference :service_events, :deleted_by, type: :uuid, foreign_key: { to_table: :users }
    add_index :service_events, :deleted_at
  end
end
