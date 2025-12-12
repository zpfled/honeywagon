class Order < ApplicationRecord
  belongs_to :customer
  belongs_to :location

  has_many :order_line_items, dependent: :destroy
  has_many :order_units, dependent: :destroy
  has_many :units, through: :order_units
  has_many :service_events, dependent: :destroy

  BLOCKING_STATUSES = %w[scheduled active].freeze
  STATUSES = %w[draft scheduled active completed cancelled].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  before_save :recalculate_totals
  after_save  :sync_unit_statuses, if: :saved_change_to_status?

  STATUSES.each do |status_name|
    define_method("#{status_name}?") { status == status_name }
  end

  scope :upcoming, -> { where('start_date >= ?', Date.today) }
  scope :active_on, ->(date) { where('start_date <= ? AND end_date >= ?', date, date) }

  def activate!
    update!(status: 'active')
  end

  def schedule!
    update!(status: 'scheduled')
  end

  def complete!
    update!(status: 'completed')
  end

  def cancel!
    update!(status: 'cancelled')
  end

    def affecting_unit_status?
    %w[scheduled active completed cancelled].include?(status)
  end

  def marks_units_rented?
    %w[scheduled active].include?(status)
  end

  def releases_units?
    %w[completed cancelled].include?(status)
  end

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
end
