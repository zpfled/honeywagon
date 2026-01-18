# Trailer tracks tow-behind capacity for transporting units.
class Trailer < ApplicationRecord
  belongs_to :company
  has_many :routes, dependent: :nullify

  validates :name, :identifier, presence: true
  validates :capacity_spots, numericality: { greater_than_or_equal_to: 0 }
  validates :preference_rank, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true

  def label
    [ name, identifier ].compact.join(' • ')
  end
end
