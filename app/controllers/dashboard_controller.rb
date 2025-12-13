class DashboardController < ApplicationController
  def index
    @service_events = current_user.service_events.upcoming_week.includes(order: [ :customer, :location ])
    metrics = Dashboard::InventoryMetrics.new(company: current_user.company).call
    @inventory_stats = metrics[:inventory_stats]
    @ytd_order_total_cents = metrics[:ytd_order_total_cents]
  end
end
