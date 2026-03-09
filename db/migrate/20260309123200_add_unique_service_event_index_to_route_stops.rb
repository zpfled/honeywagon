class AddUniqueServiceEventIndexToRouteStops < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_route_stops_on_service_event_id_unique"

  def up
    return if index_exists?(:route_stops, :service_event_id, unique: true, name: INDEX_NAME)

    add_index :route_stops, :service_event_id, unique: true, name: INDEX_NAME
  end

  def down
    remove_index :route_stops, name: INDEX_NAME if index_exists?(:route_stops, :service_event_id, name: INDEX_NAME)
  end
end
