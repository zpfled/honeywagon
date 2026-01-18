# Stores cached straight-line distance between two locations.
class LocationDistance < ApplicationRecord
  belongs_to :from_location, class_name: 'Location'
  belongs_to :to_location, class_name: 'Location'

  validates :distance_km, numericality: { greater_than_or_equal_to: 0 }
  validates :from_location_id, uniqueness: { scope: :to_location_id }
end
