class CreateRoutes < ActiveRecord::Migration[7.0]
  def change
    create_table :routes, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.date :route_date, null: false
      t.timestamps
    end

    add_index :routes, [ :company_id, :route_date ]
    add_foreign_key :routes, :companies

    change_table :service_events do |t|
      t.uuid :route_id
      t.date :route_date
      t.date :completed_on
    end

    add_index :service_events, :route_id
    add_foreign_key :service_events, :routes
  end
end
