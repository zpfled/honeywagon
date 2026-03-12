class DropRouteDateFromRouteStops < ActiveRecord::Migration[8.1]
  def change
    remove_column :route_stops, :route_date, :date if column_exists?(:route_stops, :route_date)
  end
end
