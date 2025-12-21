# ServiceEvent represents a scheduled operational task for an order (delivery,
# recurring service, pickup) and tracks its completion state.
class ServiceEvent < ApplicationRecord
  default_scope { where(deleted_at: nil) }

  belongs_to :order, optional: true
  belongs_to :service_event_type
  belongs_to :user
  belongs_to :route, optional: true
  belongs_to :deleted_by, class_name: 'User', optional: true
  has_one :service_event_report, dependent: :destroy
  belongs_to :dump_site, optional: true

  enum :event_type, { delivery: 0, service: 1, pickup: 2, dump: 3 }, prefix: true
  enum :status, { scheduled: 0, completed: 1 }, prefix: true

  validates :scheduled_on, presence: true
  validate :enforce_logistics_schedule
  validates :dump_site, presence: true, if: :event_type_dump?

  before_validation :assign_service_event_type, if: -> { service_event_type_id.blank? && event_type.present? }
  before_validation :inherit_user_from_order, if: -> { order.present? && user_id.blank? }
  before_validation :default_route_date
  before_validation :assign_route_sequence, on: :create
  before_validation :reset_route_sequence_for_new_route, if: -> { will_save_change_to_route_id? && route_id.present? }
  after_update_commit :ensure_report_for_completion, if: :saved_change_to_status?
  after_update_commit :stamp_completed_on, if: -> { saved_change_to_status? && status_completed? }
  before_destroy :remember_route_for_cleanup
  before_destroy :remember_route_for_cleanup
  after_commit :auto_assign_route, on: :create
  after_commit :refresh_truck_waste_load, if: :affects_truck_waste_load?
  after_commit :cleanup_empty_routes, on: [ :update, :destroy ]

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

  # Whether the event type requires a completion report.
  def report_required?
    service_event_type&.requires_report?
  end

  def estimated_gallons_pumped
    ServiceEvents::GallonsEstimator.call(self)
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
    rental_units = order&.rental_line_items&.sum(:quantity) || 0

    case event_type.to_sym
    when :delivery, :pickup
      rental_units
    when :dump
      0
    else
      service_units = order&.service_line_items&.sum(:units_serviced) || 0
      rental_units + service_units
    end
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

  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :deleted, -> { with_deleted.where.not(deleted_at: nil) }

  def soft_delete!(user:)
    update!(deleted_at: Time.current, deleted_by: user)
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

  def default_route_date
    self.route_date ||= route&.route_date || scheduled_on
  end

  def assign_route_sequence
    return unless route_id.present? && route_sequence.nil?

    max_sequence = ServiceEvent.where(route_id: route_id).maximum(:route_sequence)
    self.route_sequence = max_sequence.to_i + 1
  end

  def reset_route_sequence_for_new_route
    self.route_sequence = nil
    assign_route_sequence
  end

  def auto_assign_route
    return if route_id.present? || order.blank?

    Routes::ServiceEventRouter.new(self).call
  end

  def delivery_route_date
    route_date || route&.route_date || scheduled_on
  end

  def refresh_truck_waste_load
    affected_trucks = []
    affected_trucks << route&.truck if route&.truck.present?

    if saved_change_to_route_id?
      previous_route_id = saved_change_to_route_id.first
      if previous_route_id
        previous_route = Route.find_by(id: previous_route_id)
        affected_trucks << previous_route&.truck
      end
    end

    affected_trucks.compact.uniq.each(&:recalculate_waste_load!)
  end

  def affects_truck_waste_load?
    status_transition_affects_load? ||
      (status_completed? && (saved_change_to_estimated_gallons_override? ||
                             previous_changes.key?('deleted_at') ||
                             saved_change_to_route_id?))
  end

  def status_transition_affects_load?
    return false unless saved_change_to_status?

    status_completed? || saved_change_to_status&.first == 'completed'
  end

  def enforce_logistics_schedule
    return if scheduled_on.blank? || route_date.blank?

    if event_type_delivery? && route_date > scheduled_on
      errors.add(:route_date, 'cannot be after the scheduled date for deliveries')
    end

    if event_type_pickup? && route_date < scheduled_on
      errors.add(:route_date, 'cannot be before the scheduled date for pickups')
    end
  end

  def cleanup_empty_routes
    previous_id = saved_change_to_route_id? ? saved_change_to_route_id.first : @route_id_for_cleanup
    Routes::Lifecycle.after_service_event_change(self, previous_route_id: previous_id)
  end

  def remember_route_for_cleanup
    @route_id_for_cleanup = route_id
  end
end
