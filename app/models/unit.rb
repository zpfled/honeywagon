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
  # Scope returning units available for the given date range.
  scope :available_between, ->(start_date, end_date) do
    return none if start_date.blank? || end_date.blank?

    overlapping_orders = Order
      .where.not(status: %w[cancelled completed])
      .where('orders.start_date <= ? AND orders.end_date >= ?', end_date, start_date)

    where(status: 'available')
      .where.not(id: OrderUnit.where(order_id: overlapping_orders.select(:id)).select(:unit_id))
  end

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
