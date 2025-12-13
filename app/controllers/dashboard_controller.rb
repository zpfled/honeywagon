class DashboardController < ApplicationController
  def index
    @service_events = current_user.service_events.upcoming_week.includes(order: [ :customer, :location ])
  end
end
