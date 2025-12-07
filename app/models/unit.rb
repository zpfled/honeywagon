class Unit < ApplicationRecord
  belongs_to :unit_type

  STATUSES = %w[available rented maintenance retired].freeze

  def available? = status == "available"
  def rented?    = status == "rented"
end
