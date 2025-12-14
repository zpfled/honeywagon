class DashboardController < ApplicationController
  def index
    @routes = current_user.company.routes.upcoming
                          .includes(:truck, :trailer,
                                    service_events: [ order: [ :customer, :location, { order_line_items: :unit_type } ] ])
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
