class AddSeptageLoadToTrucks < ActiveRecord::Migration[7.1]
  def up
    add_column :trucks, :septage_load_gal, :integer, null: false, default: 0

    say_with_time 'Backfilling septage load for trucks' do
      Truck.find_each do |truck|
        load = ServiceEvent
               .joins(:route)
               .where(routes: { truck_id: truck.id })
               .where(status: ServiceEvent.statuses[:completed])
               .sum do |event|
                 event.estimated_gallons_pumped
               end
        truck.update_columns(septage_load_gal: load)
      end
    end
  end

  def down
    remove_column :trucks, :septage_load_gal
  end
end
