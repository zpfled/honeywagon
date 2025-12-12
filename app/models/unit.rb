class Unit < ApplicationRecord
  belongs_to :unit_type

  has_many :order_units, dependent: :nullify
  has_many :orders, through: :order_units

  STATUSES = %w[available rented maintenance retired].freeze

  before_validation :assign_serial, on: :create
  validates :serial, presence: true, uniqueness: true

  # A unit is available in a window if:
  # - its status is "available"
  # - and it is NOT on any order with blocking status whose dates overlap [start_date, end_date]
  scope :available_between, ->(start_date, end_date) {
    blocking_order_ids = Order
      .where(status: Order::BLOCKING_STATUSES)
      .where('start_date <= ? AND end_date >= ?', end_date, start_date)
      .joins(:units)
      .select('units.id')

    where(status: 'available').where.not(id: blocking_order_ids)
  }

  def available? = status == 'available'
  def rented?    = status == 'rented'

  private

  def assign_serial
    return if serial.present?

    UnitType.transaction do
      ut = UnitType.lock.find(unit_type_id)
      number = ut.next_serial
      self.serial = "#{ut.prefix}-#{number}"
      ut.update!(next_serial: number + 1)
    end
  end
end
