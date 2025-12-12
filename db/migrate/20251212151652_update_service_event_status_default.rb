class UpdateServiceEventStatusDefault < ActiveRecord::Migration[8.1]
  def up
    change_column_default :service_events, :status, 0
    ServiceEvent.where(status: nil).update_all(status: 0)
  end

  def down
    change_column_default :service_events, :status, nil
  end
end
