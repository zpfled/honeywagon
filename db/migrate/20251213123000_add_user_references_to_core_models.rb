class AddUserReferencesToCoreModels < ActiveRecord::Migration[8.1]
  def change
    add_reference :orders, :user, null: true, foreign_key: true, type: :uuid
    add_reference :service_events, :user, null: true, foreign_key: true, type: :uuid
    add_reference :service_event_reports, :user, null: true, foreign_key: true, type: :uuid
  end
end
