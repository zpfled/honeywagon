class RouteStop < ApplicationRecord
  belongs_to :route
  belongs_to :service_event
  belongs_to :created_by, class_name: 'User', optional: true

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :route_date, presence: true
  validates :service_event_id, uniqueness: { scope: :route_id }
  validates :position, uniqueness: { scope: :route_id }

  scope :ordered, -> { order(:position) }

  delegate :event_type, :status, :scheduled_on, to: :service_event, prefix: true
end
