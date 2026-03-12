class AllowNullRouteDateOnRouteStops < ActiveRecord::Migration[8.1]
  def change
    change_column_null :route_stops, :route_date, true
  end
end
