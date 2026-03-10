# ServiceEvent represents a scheduled operational task for an order (delivery,
# recurring service, pickup) and tracks its completion state.
class ServiceEvent < ApplicationRecord
  default_scope { where(deleted_at: nil) }

  belongs_to :order, optional: true
  belongs_to :service_event_type
  belongs_to :user
  belongs_to :deleted_by, class_name: 'User', optional: true
  has_many :route_stops, dependent: :destroy
  has_one :primary_route_stop, -> { order(:position) }, class_name: 'RouteStop'
  has_one :route, through: :primary_route_stop
  has_one :service_event_report, dependent: :destroy
  belongs_to :dump_site, optional: true
  has_many :service_event_units, dependent: :destroy

  enum :event_type, { delivery: 0, service: 1, pickup: 2, dump: 3, refill: 4 }, prefix: true
  enum :status, { scheduled: 0, completed: 1, skipped: 2 }, prefix: true

  validates :scheduled_on, presence: true
  validates :skip_reason, presence: true, if: :status_skipped?
  validates :skipped_on, presence: true, if: :status_skipped?
  validate :enforce_logistics_schedule
  validates :dump_site, presence: true, if: :event_type_dump?

  before_validation :assign_service_event_type, if: -> { service_event_type_id.blank? && event_type.present? }
  before_validation :inherit_user_from_order, if: -> { order.present? && user_id.blank? }
  after_update_commit :ensure_report_for_completion, if: :saved_change_to_status?
  after_update_commit :stamp_completed_on, if: -> { saved_change_to_status? && status_completed? }
  after_update_commit :stamp_skipped_on, if: -> { saved_change_to_status? && status_skipped? }
  after_update_commit :complete_order_after_pickup, if: -> { saved_change_to_status? && status_completed? && event_type_pickup? }
  after_commit :refresh_truck_waste_load, if: :affects_truck_waste_load?
  after_commit :auto_assign_route, on: :create

  # Scope returning only auto-generated events that can be safely regenerated.
  scope :auto_generated, -> { where(auto_generated: true) }
  # Scope narrowing events to a date range.
  scope :scheduled_between, ->(range) { where(scheduled_on: range) }
  # Scope returning scheduled events within the next seven days, ordered.
  scope :upcoming_week, lambda {
    today = Date.current
    horizon = today + 6.days
    where(status: :scheduled).where(ServiceEvent.arel_table[:scheduled_on].lteq(horizon))
      .order(:scheduled_on, :event_type)
  }
  scope :scheduled, -> { where(status: :scheduled) }
  scope :not_skipped, -> { where.not(status: statuses[:skipped]) }

  # Whether the event type requires a completion report.
  def report_required?
    return false if status_skipped?

    service_event_type&.requires_report?
  end

  def estimated_gallons_pumped
    ServiceEvents::WasteGallonsEstimator.call(self)
  end

  def logistics_locked?
    event_type_delivery? || event_type_pickup?
  end

  def prevent_move_earlier?
    event_type_pickup?
  end

  def prevent_move_later?
    event_type_delivery?
  end

  def units_impacted_count
    rental_units = units_by_type.values.sum

    case event_type.to_sym
    when :delivery, :pickup
      rental_units
    when :dump
      0
    when :refill
      0
    else
      service_units = order&.service_line_items&.sum(:units_serviced) || 0
      rental_units + service_units
    end
  end

  def units_by_type
    return {} unless order

    if service_event_units.loaded? ? service_event_units.any? : service_event_units.exists?
      service_event_units.includes(:unit_type).each_with_object(Hash.new(0)) do |item, memo|
        unit_type = item.unit_type
        next unless unit_type
        memo[unit_type] += item.quantity.to_i
      end
    else
      line_items =
        if order.association(:rental_line_items).loaded?
          if order.rental_line_items.empty?
            order.rental_line_items.includes(:unit_type).load
          else
            order.rental_line_items
          end
        else
          order.rental_line_items.includes(:unit_type)
        end
      line_items.each_with_object(Hash.new(0)) do |item, memo|
        unit_type = item.unit_type
        next unless unit_type
        memo[unit_type] += item.quantity.to_i
      end
    end
  end

  def delivery_batch_label
    return nil unless event_type_delivery?
    return nil unless delivery_batch_total.to_i > 1

    "Delivery (#{delivery_batch_sequence}/#{delivery_batch_total})"
  end

  def pickup_batch_label
    return nil unless event_type_pickup?
    return nil unless pickup_batch_total.to_i > 1

    "Pickup (#{pickup_batch_sequence}/#{pickup_batch_total})"
  end

  def batch_label
    pickup_batch_label || delivery_batch_label
  end

  def overdue?
    return false unless status_scheduled?
    return false if scheduled_on.blank?

    if event_type_delivery?
      delivery_route_date.present? && delivery_route_date > scheduled_on
    else
      scheduled_on < Date.current
    end
  end

  def days_overdue
    return 0 unless overdue?

    if event_type_delivery?
      (delivery_route_date - scheduled_on).to_i
    else
      (Date.current - scheduled_on).to_i
    end
  end

  # TODO: move presentation helpers into a presenter/helper
  def humanized_leg_drive_distance
    return nil unless drive_distance_meters.to_i.positive?

    miles = drive_distance_meters.to_f / 1609.34
    "#{miles.round(1)} mi"
  end

  # TODO: move presentation helpers into a presenter/helper
  def estimated_fuel_cost_cents
    return nil unless drive_distance_meters.to_f.positive?

    assigned_route = route || route_stops.includes(:route).order(:position).first&.route
    truck = assigned_route&.truck
    mpg = truck&.miles_per_gallon.to_f
    price_cents = assigned_route&.company&.fuel_price_per_gal_cents.to_i
    return nil if mpg <= 0 || price_cents <= 0

    miles = drive_distance_meters.to_f / 1609.34
    gallons = miles / mpg
    (gallons * price_cents).round
  end

  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :deleted, -> { with_deleted.where.not(deleted_at: nil) }

  def soft_delete!(user:)
    update!(deleted_at: Time.current, deleted_by: user)
  end

  def route_date
    current_assigned_route_date
  end

  private

  # Backfills the service_event_type reference by matching the enum key.
  def assign_service_event_type
    type = ServiceEventType.find_by(key: event_type)
    self.service_event_type = type if type
  end

  def inherit_user_from_order
    self.user ||= order&.created_by || order&.company&.users&.first
  end

  # Ensures a ServiceEventReport exists when the event flips to completed.
  def ensure_report_for_completion
    return unless status_completed?
    return unless report_required?

    service_event_report || create_service_event_report!(data: default_report_data, user: user)
  end

  # Builds default JSON data for the report using the configured fields.
  def default_report_data
    fields = Array(service_event_type&.report_fields)
    fields.each_with_object({}) do |field, memo|
      key = field['key'] || field[:key]
      memo[key] = inferred_report_value(key)
    end
  end

  # Attempts to infer an initial value per report field key.
  def inferred_report_value(key)
    case key.to_s
    when 'customer_name'
      order.customer&.display_name
    when 'customer_address'
      [ order.location&.street, order.location&.city, order.location&.state, order.location&.zip ].compact.join(', ').presence
    when 'estimated_gallons_pumped', 'units_pumped'
      nil
    else
      nil
    end
  end

  def stamp_completed_on
    update_column(:completed_on, Date.current)
  end

  def stamp_skipped_on
    return if skipped_on.present?

    update_column(:skipped_on, Date.current)
  end

  def complete_order_after_pickup
    return unless order.present?

    order.update!(status: 'completed', end_date: Date.current)
  end

  def uncompletion_allowed?
    return false unless status_completed?

    report = service_event_report
    return true unless report.present?

    gallons = completion_report_gallons(report)
    gallons.nil? || gallons.to_i.zero?
  end

  def completion_report_gallons(report)
    return nil unless report

    raw = if event_type_dump?
            report.data['estimated_gallons_dumped']
    else
            report.data['estimated_gallons_pumped']
    end

    return nil if raw.blank?
    raw.to_i
  end

  public :uncompletion_allowed?

  def auto_assign_route
    return if primary_route_stop.present? || order.blank?

    Routes::ServiceEventRouter.new(self).call
  end

  def delivery_route_date
    current_assigned_route_date || scheduled_on
  end

  def refresh_truck_waste_load
    route_stops.includes(route: :truck).map(&:route).compact.uniq.each do |assigned_route|
      assigned_route.truck&.recalculate_waste_load!
    end
  end

  def affects_truck_waste_load?
    saved_change_to_status? ||
      saved_change_to_estimated_gallons_override? ||
      saved_change_to_event_type? ||
      previous_changes.key?('deleted_at')
  end

  def enforce_logistics_schedule
    assigned_route_date = current_assigned_route_date
    return if scheduled_on.blank? || assigned_route_date.blank?

    if event_type_delivery? && assigned_route_date > scheduled_on
      errors.add(:route_date, 'cannot be after the scheduled date for deliveries')
    end

    if event_type_pickup? && assigned_route_date < scheduled_on
      errors.add(:route_date, 'cannot be before the scheduled date for pickups')
    end
  end

  def current_assigned_route_date
    route_stops.joins(:route).order(:position).limit(1).pick('routes.route_date')
  end
end
