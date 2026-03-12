class DropRouteGenerationRunsAndRouteGenerationFk < ActiveRecord::Migration[8.1]
  def up
    if table_exists?(:routes) && column_exists?(:routes, :generation_run_id)
      remove_foreign_key :routes, column: :generation_run_id if foreign_key_exists?(:routes, column: :generation_run_id)
      remove_index :routes, :generation_run_id if index_exists?(:routes, :generation_run_id)
      remove_column :routes, :generation_run_id
    end

    drop_table :route_generation_runs if table_exists?(:route_generation_runs)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "route_generation_runs removal is irreversible"
  end
end
