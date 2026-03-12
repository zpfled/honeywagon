class AddSkipFieldsToServiceEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :service_events, :skipped_on, :date
    add_column :service_events, :skip_reason, :text
  end
end
