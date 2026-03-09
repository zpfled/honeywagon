class RouteStop < ApplicationRecord
  self.ignored_columns += [ "route_date" ]

  belongs_to :route
  belongs_to :service_event
  belongs_to :created_by, class_name: 'User', optional: true

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_event_id, uniqueness: { scope: :route_id }
  validates :position, uniqueness: { scope: :route_id }

  scope :ordered, -> { order(:position) }

  delegate :event_type, :status, :scheduled_on, to: :service_event, prefix: true

  # Route date is sourced from the parent route; persisted route_stops.route_date
  # is deprecated and ignored.
  def route_date
    route&.route_date
  end

  # Accept legacy assignment calls but ignore to avoid UnknownAttribute errors.
  def route_date=(_value); end
end
