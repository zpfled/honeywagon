class BackfillServiceEventTypes < ActiveRecord::Migration[8.1]
  class GenericServiceEvent < ApplicationRecord
    self.table_name = "service_events"
  end

  class GenericServiceEventType < ApplicationRecord
    self.table_name = "service_event_types"
  end

  EVENT_TYPE_VALUES = {
    "delivery" => 0,
    "service" => 1,
    "pickup" => 2
  }.freeze

  def up
    GenericServiceEventType.find_each do |type|
      value = EVENT_TYPE_VALUES[type.key]
      next if value.nil?

      GenericServiceEvent.where(service_event_type_id: nil, event_type: value).update_all(service_event_type_id: type.id)
    end

    change_column_null :service_events, :service_event_type_id, false
  end

  def down
    change_column_null :service_events, :service_event_type_id, true
  end
end
