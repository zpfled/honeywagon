class DropLegacyServiceEventRouteColumns < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:service_events)

    if column_exists?(:service_events, :route_id)
      remove_foreign_key :service_events, :routes if foreign_key_exists?(:service_events, :routes)
      remove_index :service_events, :route_id if index_exists?(:service_events, :route_id)
      remove_column :service_events, :route_id
    end

    remove_column :service_events, :route_date if column_exists?(:service_events, :route_date)
    remove_column :service_events, :route_sequence if column_exists?(:service_events, :route_sequence)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'legacy service_event route columns removal is irreversible'
  end
end
