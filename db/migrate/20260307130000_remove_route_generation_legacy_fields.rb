class RemoveRouteGenerationLegacyFields < ActiveRecord::Migration[8.1]
  def change
    remove_column :routes, :run_status, :string
    remove_column :route_generation_runs, :selected_for_calendar, :boolean
  end
end
