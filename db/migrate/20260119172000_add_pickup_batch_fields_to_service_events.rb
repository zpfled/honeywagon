class AddPickupBatchFieldsToServiceEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :service_events, :pickup_batch_sequence, :integer
    add_column :service_events, :pickup_batch_total, :integer
  end
end
