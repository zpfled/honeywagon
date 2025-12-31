class DashboardController < ApplicationController
  def index
    # TODO: View reads:
    # - @routes (iterated; DashboardRowPresenter built in view)
    # - @waste_loads (per-route waste summary)
    # - @trucks, @trailers (new route form)
    # - @new_route (form model)
    # - @inventory_stats, @ytd_order_total_cents (header stats)
    # TODO: Changes needed:
    # - Move DashboardRowPresenter instantiation out of the view (build collection in controller/presenter).
    # - Preload associations used by DashboardRowPresenter (service_events -> order -> customer/location, dump_site -> location).
    base_scope = current_user.company.routes.upcoming
                                   .includes(:truck, :trailer, service_events: { order: %i[customer location] })
    if ServiceEvent.where(route_id: base_scope.select(:id), event_type: ServiceEvent.event_types[:dump]).exists?
      base_scope = base_scope.includes(service_events: { dump_site: :location })
    end
    @routes = base_scope
    tracker = Routes::WasteTracker.new(@routes)
    @waste_loads = tracker.loads_by_route_id
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
end
