class AddGoogleCalendarFields < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_calendar_access_token, :string
    add_column :users, :google_calendar_refresh_token, :string
    add_column :users, :google_calendar_expires_at, :datetime

    add_column :service_events, :google_calendar_event_id, :string
  end
end
