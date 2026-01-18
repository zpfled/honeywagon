class AddGoogleCalendarSyncHashToRoutes < ActiveRecord::Migration[8.1]
  def change
    add_column :routes, :google_calendar_sync_hash, :string
  end
end
