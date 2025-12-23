class AddEstimatedCostToServiceEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :service_events, :estimated_cost_cents, :integer, null: false, default: 0
  end
end
