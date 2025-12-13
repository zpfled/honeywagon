class SetUserNullFalseOnCoreModels < ActiveRecord::Migration[8.1]
  def change
    change_column_null :orders, :user_id, false
    change_column_null :service_events, :user_id, false
    change_column_null :service_event_reports, :user_id, false
  end
end
