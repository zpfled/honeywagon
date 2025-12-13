# UnitType defines the categories of rentable assets (standard, ADA, wash).
class UnitType < ApplicationRecord
  has_many :units, dependent: :nullify

  TYPES = [
    { name: 'Standard Unit', slug: 'standard', prefix: 'S' },
    { name: 'ADA Accessible Unit', slug: 'ada', prefix: 'A' },
    { name: 'Handwash Station', slug: 'handwash', prefix: 'W' }
  ].freeze

  validates :prefix, presence: true, format: { with: /\A[A-Z]\z/ }

  # Returns the human-friendly name when interpolated.
  def to_s = name
end
