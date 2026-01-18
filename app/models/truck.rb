# Truck represents a service vehicle with pumping and water capacities.
class Truck < ApplicationRecord
  belongs_to :company
  has_many :routes, dependent: :nullify

  validates :name, :number, presence: true
  validates :clean_water_capacity_gal, :waste_capacity_gal,
            numericality: { greater_than_or_equal_to: 0 }
  validates :miles_per_gallon, numericality: { greater_than: 0 }, allow_nil: true
  validates :preference_rank, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true

  def label
    [ name, number ].compact.join(' • ')
  end

  def recalculate_waste_load!
    events = ServiceEvent
             .joins(:route)
             .where(routes: { truck_id: id })
             .where(status: ServiceEvent.statuses[:completed])
             .order(Arel.sql('service_events.updated_at ASC'))

    total = 0
    events.each do |event|
      if event.event_type_dump?
        total = 0
      else
        total += event.estimated_gallons_pumped
      end
    end

    update_columns(waste_load_gal: total)
  end
end
