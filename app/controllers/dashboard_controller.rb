class DashboardController < ApplicationController
  before_action :ensure_capacity_routing_access!, only: :capacity_routing_preview

  def index
    base_scope = current_user.company.routes.upcoming
                                   .includes(:truck, :trailer, service_events: [ { service_event_units: :unit_type }, { order: %i[customer location] } ])
    if ServiceEvent.where(route_id: base_scope.select(:id), event_type: ServiceEvent.event_types[:dump]).exists?
      base_scope = base_scope.includes(service_events: { dump_site: :location })
    end
    @routes = base_scope
    tracker = Routes::WasteTracker.new(@routes)
    @waste_loads = tracker.ending_loads_by_route_id
    @dashboard_rows = @routes.map do |route|
      Routes::DashboardRowPresenter.new(route, waste_load: @waste_loads[route.id])
    end
    @trucks = current_user.company.trucks.order(:name, :number)
    @trailers = current_user.company.trailers.order(:name, :identifier)
    @new_route = current_user.company.routes.new(
      route_date: Date.current,
      truck: @trucks.first,
      trailer: @trailers.first
    )
    metrics = Dashboard::InventoryMetrics.new(company: current_user.company).call
    @inventory_stats = metrics[:inventory_stats]
    @ytd_order_total_cents = metrics[:ytd_order_total_cents]
  end

  def capacity_routing_preview
    result = Routes::CapacityRouting::Planner.call(company: current_user.company, start_date: Date.current)
    @preview = Routes::CapacityRoutingPreviewPresenter.new(result: result, company: current_user.company)
  end

  private

  def ensure_capacity_routing_access!
    return if current_user&.admin? || current_user&.dispatcher?

    redirect_to authenticated_root_path, alert: 'Only admins or dispatchers can run capacity routing previews.'
  end
end
