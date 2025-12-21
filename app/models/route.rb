class Route < ApplicationRecord
  attr_accessor :skip_auto_assign

  belongs_to :company
  belongs_to :truck
  belongs_to :trailer, optional: true
  has_many :service_events, dependent: :nullify
  has_many :service_events_with_deleted, -> { with_deleted }, class_name: 'ServiceEvent'

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
  before_destroy :nullify_deleted_service_events
  after_create -> { Routes::Lifecycle.after_route_create(self) }
  after_update_commit -> { Routes::Lifecycle.after_route_update(self) }

  scope :upcoming, lambda {
    today = Time.use_zone('Central Time (US & Canada)') { Time.zone.today }
    horizon = today + 13.days
    where(route_date: today..horizon).order(:route_date)
  }

  def service_event_count = service_events.count
  def estimated_gallons = service_events.sum(&:estimated_gallons_pumped)
  def deliveries_count = service_events.event_type_delivery.count
  def services_count = service_events.event_type_service.count
  def pickups_count = service_events.event_type_pickup.count
  def delivery_unit_breakdown = unit_breakdown_for(service_events.event_type_delivery)
  def pickup_unit_breakdown = unit_breakdown_for(service_events.event_type_pickup)
  def delivery_units_total = unit_total_for(service_events.event_type_delivery)
  def pickup_units_total = unit_total_for(service_events.event_type_pickup)
  def serviced_units_count
    service_scope = service_events.event_type_service
    rental_units = units_impacted_for(service_scope)
    service_line_units = service_scope.joins(order: :service_line_items).sum('service_line_items.units_serviced')
    rental_units + service_line_units
  end

  def record_drive_metrics(seconds:, meters:)
    update!(
      estimated_drive_seconds: seconds,
      estimated_drive_meters: meters,
      optimization_stale: false
    )
  end

  def humanized_drive_time
    return nil unless estimated_drive_seconds.to_i.positive?

    hours = estimated_drive_seconds / 3600
    minutes = (estimated_drive_seconds % 3600) / 60

    if hours.positive?
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end

  def humanized_drive_distance
    return nil unless estimated_drive_meters.to_i.positive?

    miles = estimated_drive_meters / 1609.34
    "#{miles.round(1)} mi"
  end

  def capacity_summary = Routes::CapacitySummary.new(route: self)
  delegate :over_capacity?, :over_capacity_dimensions, :trailer_usage, :clean_water_usage, :waste_usage,
           to: :capacity_summary

  def resequence_service_events!(ordered_ids)
    transaction do
      events = service_events.index_by(&:id)
      sequence = 0

      Array(ordered_ids).each do |id|
        event = events.delete(id)
        next unless event

        event.update!(route_sequence: sequence)
        sequence += 1
      end

      events.values.sort_by { |event| event.route_sequence.to_i }.each do |event|
        event.update!(route_sequence: sequence)
        sequence += 1
      end
    end
  end

  private

  def set_default_date
    self.route_date ||= Date.current
  end

  def assign_default_assets
    return unless company
    self.truck ||= company.trucks.first
    self.trailer = nil if new_record? && trailer.nil?
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
             .joins(order: :rental_line_items)
             .group('rental_line_items.unit_type_id')
             .sum('rental_line_items.quantity')

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
      .joins(order: :rental_line_items)
      .sum('rental_line_items.quantity')
  end

  def unit_total_for(events_scope)
    events_scope
      .joins(order: :rental_line_items)
      .sum('rental_line_items.quantity')
  end

  def nullify_deleted_service_events
    service_events_with_deleted.where.not(deleted_at: nil).update_all(route_id: nil)
  end
end
