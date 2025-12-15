# ServiceEvent represents a scheduled operational task for an order (delivery,
# recurring service, pickup) and tracks its completion state.
class ServiceEvent < ApplicationRecord
  default_scope { where(deleted_at: nil) }

  belongs_to :order
  belongs_to :service_event_type
  belongs_to :user
  belongs_to :route, optional: true
  belongs_to :deleted_by, class_name: 'User', optional: true
  has_one :service_event_report, dependent: :destroy

  enum :event_type, { delivery: 0, service: 1, pickup: 2 }, prefix: true
  enum :status, { scheduled: 0, completed: 1 }, prefix: true

  validates :scheduled_on, presence: true

  before_validation :assign_service_event_type, if: -> { service_event_type_id.blank? && event_type.present? }
  before_validation :inherit_user_from_order, if: -> { order.present? && user_id.blank? }
  before_validation :default_route_date
  after_update_commit :ensure_report_for_completion, if: :saved_change_to_status?
  after_update_commit :stamp_completed_on, if: -> { saved_change_to_status? && status_completed? }
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

  # Whether the event type requires a completion report.
  def report_required?
    service_event_type&.requires_report?
  end

  def estimated_gallons_pumped
    return 0 if event_type_delivery?

    targeted_unit_types = order.rental_line_items
                               .joins(:unit_type)
                               .where(unit_types: { slug: %w[standard ada] })
    targeted_unit_types.sum(:quantity) * 10
  end

  def units_impacted_count
    order.rental_line_items.sum(:quantity)
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

  def auto_assign_route
    return if route_id.present? || order.blank?

    Routes::ServiceEventRouter.new(self).call
  end
end
