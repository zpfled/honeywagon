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

    column = has_attribute?(:waste_load_gal) ? :waste_load_gal : :septage_load_gal
    update_columns(column => total)
  end

  # Backwards-compatible alias used by older migrations/tests.
  alias_method :recalculate_septage_load!, :recalculate_waste_load!

  def waste_capacity_gal
    read_waste_attribute(:waste_capacity_gal)
  end

  def waste_capacity_gal=(value)
    write_waste_attribute(:waste_capacity_gal, value)
  end

  def waste_load_gal
    read_waste_attribute(:waste_load_gal)
  end

  def waste_load_gal=(value)
    write_waste_attribute(:waste_load_gal, value)
  end

  private

  def read_waste_attribute(attr)
    if has_attribute?(attr)
      self[attr]
    else
      legacy_attr = legacy_waste_attribute(attr)
      self[legacy_attr]
    end
  end

  def write_waste_attribute(attr, value)
    column = has_attribute?(attr) ? attr : legacy_waste_attribute(attr)
    self[column] = value
  end

  def legacy_waste_attribute(attr)
    case attr
    when :waste_capacity_gal then :septage_capacity_gal
    when :waste_load_gal then :septage_load_gal
    else
      attr
    end
  end
end
