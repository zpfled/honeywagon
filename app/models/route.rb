class Route < ApplicationRecord
  require 'digest'
  attr_accessor :skip_auto_assign

  belongs_to :company
  belongs_to :truck
  belongs_to :trailer, optional: true
  has_many :route_stops, dependent: :destroy
  has_many :service_events, -> { distinct }, through: :route_stops, source: :service_event
  has_many :service_events_with_deleted, -> { with_deleted.distinct }, through: :route_stops, source: :service_event
  has_many :stop_service_events, through: :route_stops, source: :service_event

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
  after_create -> { Routes::Lifecycle.after_route_create(self) }
  after_update_commit -> { Routes::Lifecycle.after_route_update(self) }

  scope :upcoming, lambda {
    today = Time.use_zone('Central Time (US & Canada)') { Time.zone.today }
    horizon = today + 27.days
    where(route_date: today..horizon).order(:route_date)
  }

  def service_event_count = service_events.size
  # TODO: Move display-oriented aggregates to presenter; remove once index/show migrate.
  def estimated_gallons = service_events.sum(&:estimated_gallons_pumped)
  # TODO: handled by RoutePresenter; keep until views migrate
  def deliveries_count = service_events.event_type_delivery.count
  # TODO: handled by RoutePresenter; keep until views migrate
  def services_count = service_events.event_type_service.count
  # TODO: handled by RoutePresenter; keep until views migrate
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

  def ordered_route_stops
    route_stops.order(:position)
  end

  def ordered_service_event_ids(not_skipped: false)
    scope = ordered_service_event_scope
    scope = scope.not_skipped if not_skipped
    scope.pluck(:id)
  end

  def ordered_service_event_relation(not_skipped: false)
    scope = ordered_service_event_scope
    scope = scope.not_skipped if not_skipped
    scope
  end

  def ordered_service_event_scope
    ServiceEvent
      .joins(:route_stops)
      .where(route_stops: { route_id: id })
      .order('route_stops.position ASC')
  end

  def has_stop_projection?
    route_stops.loaded? ? route_stops.any? : route_stops.exists?
  end

  def stop_for_event(event)
    return unless has_stop_projection?

    stop_service_hash[event&.id]
  end

  def stop_position_for(event)
    stop_for_event(event)&.position
  end

  def append_service_event_stop!(service_event, position: nil, created_by: nil)
    return if service_event.blank?

    stop_position = position.presence || (route_stops.maximum(:position).to_i + 1)
    route_stops.create!(
      service_event: service_event,
      position: stop_position,
      status: service_event.status,
      created_by: created_by
    )
    stop_position
  end

  def remove_service_event_stop!(service_event)
    stop = route_stops.find_by(service_event_id: service_event.id)
    return if stop.blank?

    stop.destroy!
    synchronize_route_sequence_with_stops! if has_stop_projection?
  end

  def synchronize_route_sequence_with_stops!
    return unless has_stop_projection?

    ordered_route_stops.each_with_index do |stop, index|
      next if stop.position == index

      stop.update_column(:position, index)
    end
    @stop_service_hash = nil
  end

  def ordered_service_events
    ordered_service_event_scope.to_a
  end

  def ordered_stops_or_events
    ordered_route_stops.includes(:service_event).to_a
  end

  def route_position_label(event)
    stop_position_for(event)
  end

  def has_operational_stops?
    has_stop_projection? && route_stops.any?
  end

  def google_calendar_hash
    ordered_events = ordered_service_events.to_a
    digest_input = ordered_events.map.with_index do |event, index|
      [
        event&.id,
        stop_position_for(event) || index,
        event&.scheduled_on
      ].join(':')
    end.join('|')

    Digest::SHA256.hexdigest([ route_date, digest_input ].join('::'))
  end

  def record_drive_metrics(seconds:, meters:)
    update!(
      estimated_drive_seconds: seconds,
      estimated_drive_meters: meters,
      optimization_stale: false
    )
  end

  def record_stop_drive_metrics(event_ids:, legs: [])
    legs ||= []
    events = service_events.where(id: event_ids).index_by(&:id)
    leading_legs = [ legs.length - events.length, 0 ].max
    legs_with_defaults = legs + Array.new([ events.length + leading_legs - legs.length, 0 ].max) { { distance_meters: 0, duration_seconds: 0 } }

    ordered_ids = event_ids.compact.select { |id| events.key?(id) }
    ordered_ids.each_with_index do |event_id, index|
      event = events[event_id]
      next unless event

      leg_index = index + leading_legs - 1
      leg = leg_index.negative? ? nil : legs_with_defaults[leg_index]
      distance = leg ? leg[:distance_meters].to_i : 0
      duration_seconds = leg ? leg[:duration_seconds] : 0

      event.update!(
        drive_distance_meters: distance,
        drive_duration_seconds: duration_seconds
      )
    end
  end

  def capacity_summary = Routes::CapacitySummary.new(route: self)
  delegate :over_capacity?, :over_capacity_dimensions, :trailer_usage, :clean_water_usage, :waste_usage,
           to: :capacity_summary

  def resequence_service_events!(ordered_ids)
    transaction do
      normalized_ids = Array(ordered_ids).map(&:presence).compact.map(&:to_s)
      stop_map = ordered_route_stops.includes(:service_event).index_by { |stop| stop.service_event_id.to_s }
      ordered_stops = []

      normalized_ids.each do |id|
        stop = stop_map.delete(id)
        ordered_stops << stop if stop
      end
      ordered_stops.concat(stop_map.values.sort_by(&:position))

      # Avoid unique position collisions (route_id + position) by assigning
      # temporary unique positions first, then final contiguous positions.
      temp_base = route_stops.maximum(:position).to_i + ordered_stops.size + 100
      ordered_stops.each_with_index do |stop, index|
        stop.update_columns(position: temp_base + index)
      end
      ordered_stops.each_with_index do |stop, index|
        stop.update_columns(position: index)
      end

      @stop_service_hash = nil
    end
  end

  def assigned_service_events_count
    ordered_route_stops.count
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
    events = events_scope.includes(service_event_units: :unit_type)
    preload_rental_line_items_for(events)
    counts = Hash.new(0)

    events.each do |event|
      event.units_by_type.each do |unit_type, quantity|
        counts[unit_type] += quantity.to_i
      end
    end

    counts.map do |unit_type, quantity|
      "#{quantity} #{unit_type.name.downcase.pluralize(quantity)}"
    end
  end

  def units_impacted_for(events_scope)
    events = events_scope.includes(service_event_units: :unit_type)
    preload_rental_line_items_for(events)
    events.sum { |event| event.units_by_type.values.sum }
  end

  def unit_total_for(events_scope)
    events = events_scope.includes(service_event_units: :unit_type)
    preload_rental_line_items_for(events)
    events.sum { |event| event.units_by_type.values.sum }
  end

  # TODO: Evaluate indexes to support presenter aggregations (service_events counts/sums).

  def preload_rental_line_items_for(events)
    needs_units = events.any? do |event|
      event.order.present? && !event.event_type_dump? && !event.event_type_refill?
    end
    return unless needs_units
    return if events.any? { |event| event.service_event_units.loaded? && event.service_event_units.any? }

    orders = events.filter_map { |event| event.order if event.order.present? }.uniq
    return if orders.empty?
    return unless orders.any? { |order| order.association(:rental_line_items).loaded? ? order.rental_line_items.any? : order.rental_line_items.exists? }

    ActiveRecord::Associations::Preloader.new(records: orders, associations: { rental_line_items: :unit_type }).call
  end

  def stop_service_hash
    @stop_service_hash ||= ordered_route_stops.includes(:service_event).index_by(&:service_event_id)
  end
end
