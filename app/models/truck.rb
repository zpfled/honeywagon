# Truck represents a service vehicle with pumping and water capacities.
class Truck < ApplicationRecord
  belongs_to :company
  has_many :routes, dependent: :nullify

  validates :name, :number, presence: true
  validates :clean_water_capacity_gal, :septage_capacity_gal,
            numericality: { greater_than_or_equal_to: 0 }

  def label
    [ name, number ].compact.join(' • ')
  end
end
