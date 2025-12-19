# Truck represents a service vehicle with pumping and water capacities.
class Truck < ApplicationRecord
  belongs_to :company
  has_many :routes, dependent: :nullify

  validates :name, :number, presence: true
  validates :clean_water_capacity_gal, :septage_capacity_gal,
            numericality: { greater_than_or_equal_to: 0 }

  def label
    [ name, number ].compact.join(' • ')
  end

  def recalculate_septage_load!
    events = ServiceEvent
             .joins(:route)
             .where(routes: { truck_id: id })
             .where(status: ServiceEvent.statuses[:completed])
             .order(Arel.sql('COALESCE(service_events.completed_on, service_events.updated_at) ASC'))

    total = 0
    events.each do |event|
      if event.event_type_dump?
        total = 0
      else
        total += event.estimated_gallons_pumped
      end
    end

    update_columns(septage_load_gal: total)
  end
end
