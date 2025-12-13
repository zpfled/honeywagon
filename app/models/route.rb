class Route < ApplicationRecord
  belongs_to :company
  has_many :service_events, dependent: :nullify

  validates :route_date, presence: true

  after_initialize :set_default_date
  after_create :assign_service_events
  after_update_commit :propagate_route_date, if: -> { saved_change_to_route_date? }

  scope :upcoming, -> { where('route_date >= ?', Date.current).order(:route_date) }

  def service_event_count = service_events.count
  def estimated_gallons = service_events.sum(&:estimated_gallons_pumped)
  def deliveries_count = service_events.event_type_delivery.count
  def services_count = service_events.event_type_service.count
  def pickups_count = service_events.event_type_pickup.count
  def delivery_unit_breakdown = unit_breakdown_for(service_events.event_type_delivery)
  def pickup_unit_breakdown = unit_breakdown_for(service_events.event_type_pickup)

  private

  def set_default_date
    self.route_date ||= Date.current
  end

  def assign_service_events
    window = route_date.beginning_of_week..route_date.end_of_week
    company.service_events
           .scheduled
           .where(route_id: nil)
           .where(scheduled_on: window)
           .find_each do |event|
      event.update!(route: self, route_date: route_date)
    end
  end

  def propagate_route_date
    service_events.update_all(route_date: route_date)
  end

  def unit_breakdown_for(events_scope)
    counts = events_scope
             .joins(order: :order_line_items)
             .group('order_line_items.unit_type_id')
             .sum('order_line_items.quantity')

    unit_types = UnitType.where(id: counts.keys).index_by(&:id)

    counts.each_with_object([]) do |(unit_type_id, quantity), memo|
      unit_type = unit_types[unit_type_id]
      next unless unit_type

      label = "#{quantity} #{unit_type.name.downcase.pluralize(quantity)}"
      memo << label
    end
  end
end
