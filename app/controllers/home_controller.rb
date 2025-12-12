class HomeController < ApplicationController
  def index
    @service_events = ServiceEvent.upcoming_week.includes(order: [ :customer, :location ])
  end
end
