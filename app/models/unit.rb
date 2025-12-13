# Unit represents an individual rentable asset (toilet, ADA unit, sink, etc.).
class Unit < ApplicationRecord
  belongs_to :company
  belongs_to :unit_type

  has_many :order_units, dependent: :nullify
  has_many :orders, through: :order_units

  STATUSES = %w[available rented maintenance retired].freeze

  before_validation :assign_company_from_unit_type
  before_validation :assign_serial, on: :create
  validates :serial, presence: true, uniqueness: true

  # Scope for the standard unit type to simplify seeding/demo data.
  scope :standard, -> { includes(:unit_type).where(unit_type: { slug: 'standard' }) }
  scope :assignable, -> { where.not(status: 'retired') }
  scope :overlapping_between, lambda { |start_date, end_date, statuses = Order::BLOCKING_STATUSES|
    return none if start_date.blank? || end_date.blank?

    joins(order_units: :order)
      .where(orders: { status: statuses })
      .where('orders.start_date <= ? AND orders.end_date >= ?', end_date, start_date)
      .distinct
  }
  scope :available_between, lambda { |start_date, end_date, statuses = Order::BLOCKING_STATUSES|
    return none if start_date.blank? || end_date.blank?

    assignable.where.not(
      id: overlapping_between(start_date, end_date, statuses).select(:id)
    )
  }

  # True when the unit is in the available status.
  def available? = status == 'available'
  # True when the unit is currently rented.
  def rented?    = status == 'rented'

  private

  # Generates a serial using the unit type's prefix/counter if missing.
  def assign_serial
    return if serial.present?

    UnitType.transaction do
      ut = UnitType.lock.find(unit_type_id)
      number = ut.next_serial
      self.serial = "#{ut.prefix}-#{number}"
      ut.update!(next_serial: number + 1)
    end
  end

  def assign_company_from_unit_type
    self.company ||= unit_type&.company
  end
end
