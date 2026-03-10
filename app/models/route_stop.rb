class RouteStop < ApplicationRecord
  self.ignored_columns += [ 'route_date' ]

  belongs_to :route
  belongs_to :service_event
  belongs_to :created_by, class_name: 'User', optional: true

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_event_id, uniqueness: { scope: :route_id }
  validates :position, uniqueness: { scope: :route_id }
  after_commit :cleanup_empty_routes, on: [ :update, :destroy ]
  after_commit :mark_routes_optimization_stale, on: [ :create, :update, :destroy ]

  scope :ordered, -> { order(:position) }

  delegate :event_type, :status, :scheduled_on, to: :service_event, prefix: true

  # Route date is sourced from the parent route; persisted route_stops.route_date
  # is deprecated and ignored.
  def route_date
    route&.route_date
  end

  # Accept legacy assignment calls but ignore to avoid UnknownAttribute errors.
  def route_date=(_value); end

  private

  def cleanup_empty_routes
    route_ids = []
    route_ids << route_id if route_id.present?
    if previous_changes.key?('route_id')
      old_id, new_id = previous_changes['route_id']
      route_ids << old_id
      route_ids << new_id
    end

    route_ids.compact.uniq.each { |id| Routes::Lifecycle.cleanup_route(id) }
  end

  def mark_routes_optimization_stale
    route_ids = []
    route_ids << route_id if route_id.present?
    if previous_changes.key?('route_id')
      old_id, new_id = previous_changes['route_id']
      route_ids << old_id
      route_ids << new_id
    end

    ids = route_ids.compact.uniq
    return if ids.empty?

    Route.where(id: ids).update_all(optimization_stale: true)
  end
end
