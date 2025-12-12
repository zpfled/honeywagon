class ServiceEvent < ApplicationRecord
  belongs_to :order

  enum :event_type, { delivery: 0, service: 1, pickup: 2 }, prefix: true
  enum :status, { planned: 0, completed: 1, skipped: 2 }, prefix: true

  validates :scheduled_on, presence: true
end
