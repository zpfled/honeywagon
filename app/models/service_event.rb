# ServiceEvent represents a scheduled operational task for an order (delivery,
# recurring service, pickup).
class ServiceEvent < ApplicationRecord
  belongs_to :order

  enum :event_type, { delivery: 0, service: 1, pickup: 2 }, prefix: true
  enum :status, { scheduled: 0, completed: 1 }, prefix: true

  validates :scheduled_on, presence: true

  # Returns only the events that the system generated automatically.
  scope :auto_generated, -> { where(auto_generated: true) }
  scope :scheduled_between, ->(range) { where(scheduled_on: range) }
  scope :upcoming_week, lambda {
    today = Date.current
    horizon = today + 6.days
    where(status: :scheduled).where(ServiceEvent.arel_table[:scheduled_on].lteq(horizon))
      .order(:scheduled_on, :event_type)
  }
end
