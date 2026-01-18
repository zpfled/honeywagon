# Tracks per-event unit quantities for delivery batching.
class ServiceEventUnit < ApplicationRecord
  belongs_to :service_event
  belongs_to :unit_type

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_type_id, uniqueness: { scope: :service_event_id }
end
