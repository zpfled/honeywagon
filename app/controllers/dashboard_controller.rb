class DashboardController < ApplicationController
  def index
    @routes = current_user.company.routes.upcoming.includes(service_events: [ order: [ :customer, :location ] ])
    @new_route = current_user.company.routes.new(route_date: Date.current)
    metrics = Dashboard::InventoryMetrics.new(company: current_user.company).call
    @inventory_stats = metrics[:inventory_stats]
    @ytd_order_total_cents = metrics[:ytd_order_total_cents]
  end
end
