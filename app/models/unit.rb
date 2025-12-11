class Unit < ApplicationRecord
  belongs_to :unit_type

  has_many :order_units, dependent: :nullify
  has_many :orders, through: :order_units

  STATUSES = %w[available rented maintenance retired].freeze

  before_validation :assign_serial, on: :create
  validates :serial, presence: true, uniqueness: true

  def available? = status == "available"
  def rented?    = status == "rented"

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
