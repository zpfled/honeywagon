class AddRouteSequenceToServiceEvents < ActiveRecord::Migration[8.1]
  class MigrationServiceEvent < ApplicationRecord
    self.table_name = 'service_events'
  end

  def up
    add_column :service_events, :route_sequence, :integer
    add_index :service_events, [ :route_id, :route_sequence ]

    say_with_time 'Backfilling route_sequence for existing service events' do
      MigrationServiceEvent.unscoped.where.not(route_id: nil).order(:route_id, :created_at).group_by(&:route_id).each_value do |events|
        events.each_with_index do |event, idx|
          event.update_columns(route_sequence: idx)
        end
      end
    end
  end

  def down
    remove_index :service_events, column: [ :route_id, :route_sequence ]
    remove_column :service_events, :route_sequence
  end
end
