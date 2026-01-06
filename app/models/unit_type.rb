# UnitType defines the categories of rentable assets (standard, ADA, wash).
class UnitType < ApplicationRecord
  belongs_to :company
  has_many :units, dependent: :nullify
  has_many :rate_plans, dependent: :destroy

  TYPES = [
    { name: 'Standard Unit', slug: 'standard', prefix: 'S' },
    { name: 'ADA Accessible Unit', slug: 'ada', prefix: 'A' },
    { name: 'Handwash Station', slug: 'handwash', prefix: 'W' }
  ].freeze

  validates :prefix, presence: true, format: { with: /\A[A-Z]{1,3}\z/ }
  validates :delivery_clean_gallons, :service_clean_gallons, :service_waste_gallons,
            :pickup_clean_gallons, :pickup_waste_gallons,
            numericality: { greater_than_or_equal_to: 0 }

  # Returns the human-friendly name when interpolated.
  def to_s = name
end
