# Order models the lifecycle of a rental/service order and owns associated line
# items, units, and generated service events.
class Order < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :customer
  belongs_to :location
  belongs_to :order_series, optional: true

  has_many :rental_line_items, dependent: :destroy
  has_many :service_line_items, dependent: :destroy
  has_many :order_units, dependent: :destroy
  has_many :units, through: :order_units
  has_many :service_events, dependent: :destroy

  BLOCKING_STATUSES = %w[scheduled active].freeze
  STATUSES = %w[draft scheduled active completed cancelled].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  before_validation :assign_company_from_creator
  before_validation :set_default_status, on: :create
  before_save :recalculate_totals
  after_save  :sync_unit_statuses, if: :saved_change_to_status?
  after_commit :generate_service_events, if: :trigger_service_event_generation?

  STATUSES.each do |status_name|
    define_method("#{status_name}?") { status == status_name }
  end

  # Scope returning orders that start today or later.
  scope :upcoming, -> { where('start_date >= ?', Date.today) }
  # Scope returning orders active on the supplied date.
  scope :active_on, ->(date) { where('start_date <= ? AND end_date >= ?', date, date) }

  # Marks the order status as active and persists the change.
  def activate!
    update!(status: 'active')
  end

  # Marks the order status as scheduled and persists the change.
  def schedule!
    update!(status: 'scheduled')
  end

  # Marks the order status as completed and persists the change.
  def complete!
    update!(status: 'completed')
  end

  # Marks the order status as cancelled and persists the change.
  def cancel!
    update!(status: 'cancelled')
  end

  # Returns true when the current status should affect linked unit statuses.
  def affecting_unit_status?
    %w[scheduled active completed cancelled].include?(status)
  end

  # Returns true when units should be marked rented for the current status.
  def marks_units_rented?
    %w[scheduled active].include?(status)
  end

  # Returns true when units should be released from rental for the current status.
  def releases_units?
    %w[completed cancelled].include?(status)
  end

  # Recomputes the aggregate cents fields based on their individual components.
  def recalculate_totals
    # Normalize nils to 0 and ensure integers
    self.rental_subtotal_cents = rental_subtotal_cents.to_i
    self.delivery_fee_cents    = delivery_fee_cents.to_i
    self.pickup_fee_cents      = pickup_fee_cents.to_i
    self.discount_cents        = discount_cents.to_i
    self.tax_cents             = tax_cents.to_i

    self.total_cents =
      rental_subtotal_cents +
      delivery_fee_cents +
      pickup_fee_cents -
      discount_cents +
      tax_cents

    self
  end

  # Recalculate totals and persist immediately.
  def recalculate_totals!
    recalculate_totals
    save!
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, 'must be on or after start date') if end_date < start_date
  end

  def sync_unit_statuses
    return unless affecting_unit_status?

    if marks_units_rented?
      units.find_each do |unit|
        unit.update!(status: 'rented')
      end
    elsif releases_units?
      units.find_each do |unit|
        unit.update!(status: 'available')
      end
    end
  end

  def assign_company_from_creator
    self.company ||= created_by&.company
  end

  def set_default_status
    self.status ||= 'scheduled'
  end

  # Whether the current change should enqueue service-event generation.
  def trigger_service_event_generation?
    saved_change_to_status? && (scheduled? || active?)
  end

  # Calls the service-event generator for this order.
  def generate_service_events
    from_date = active? ? Date.current : nil
    Orders::ServiceEventGenerator.new(self, from_date: from_date).call
  end
end
