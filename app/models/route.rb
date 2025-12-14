class Route < ApplicationRecord
  attr_accessor :skip_auto_assign

  belongs_to :company
  belongs_to :truck
  belongs_to :trailer, optional: true
  has_many :service_events, dependent: :nullify

  validates :route_date, presence: true
  validates :truck, presence: true
  validate :truck_belongs_to_company
  validate :trailer_belongs_to_company

  class << self
    def without_auto_assignment
      previous = Thread.current[:route_skip_auto_assign]
      Thread.current[:route_skip_auto_assign] = true
      yield
    ensure
      Thread.current[:route_skip_auto_assign] = previous
    end

    def auto_assignment_disabled?
      Thread.current[:route_skip_auto_assign]
    end
  end

  after_initialize :set_default_date
  before_validation :assign_default_assets
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
  def serviced_units_count = units_impacted_for(service_events.event_type_service)
  def capacity_summary = Routes::CapacitySummary.new(route: self)
  delegate :over_capacity?, :over_capacity_dimensions, :trailer_usage, :clean_water_usage, :septage_usage,
           to: :capacity_summary

  private

  def set_default_date
    self.route_date ||= Date.current
  end

  def assign_default_assets
    return unless company
    self.truck ||= company.trucks.first
    self.trailer = nil if new_record? && trailer.nil?
  end

  def assign_service_events
    return if skip_auto_assign || self.class.auto_assignment_disabled?
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

  def truck_belongs_to_company
    return if truck.nil? || truck.company_id == company_id
    errors.add(:truck_id, 'must belong to the same company')
  end

  def trailer_belongs_to_company
    return if trailer.nil? || trailer.company_id == company_id
    errors.add(:trailer_id, 'must belong to the same company')
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

  def units_impacted_for(events_scope)
    events_scope
      .joins(order: :order_line_items)
      .sum('order_line_items.quantity')
  end
end
