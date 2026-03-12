class CreateRouteGenerationRunsAndRouteStops < ActiveRecord::Migration[8.1]
  def change
    create_table :route_generation_runs, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid :company_id, null: false
      t.uuid :created_by_id
      t.string :scope_key, null: false
      t.date :window_start, null: false
      t.date :window_end, null: false
      t.string :strategy, null: false, default: 'capacity_v1'
      t.integer :state, null: false, default: 0
      t.boolean :selected_for_calendar, default: false, null: false
      t.jsonb :source_params, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps

      t.index :company_id
      t.index [ :company_id, :scope_key ]
      t.index :scope_key
      t.index [ :company_id, :scope_key ], name: 'index_route_generation_runs_active',
                                            where: "state = 1",
                                            unique: true
    end

    create_table :route_stops, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid :route_id, null: false
      t.uuid :service_event_id, null: false
      t.integer :position, null: false
      t.date :route_date, null: false
      t.datetime :planned_arrival_at
      t.datetime :planned_departure_at
      t.string :status
      t.uuid :created_by_id
      t.text :notes
      t.timestamps

      t.index :route_id
      t.index :service_event_id
      t.index [ :route_id, :position ], unique: true
      t.index [ :route_id, :service_event_id ], unique: true
    end

    add_column :routes, :generation_run_id, :uuid
    add_column :routes, :run_status, :string

    add_index :routes, :generation_run_id

    add_foreign_key :route_generation_runs, :companies, column: :company_id
    add_foreign_key :route_generation_runs, :users, column: :created_by_id
    add_foreign_key :route_stops, :routes
    add_foreign_key :route_stops, :service_events
    add_foreign_key :route_stops, :users, column: :created_by_id
    add_foreign_key :routes, :route_generation_runs, column: :generation_run_id
  end
end
