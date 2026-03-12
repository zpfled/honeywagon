require "rails_helper"

RSpec.describe Routes::DayRouteClearer do
  let(:company) { create(:company) }
  let!(:truck) { create(:truck, company: company) }
  let!(:trailer) { create(:trailer, company: company) }
  let(:date) { Date.current + 3.days }

  it "clears future-day routes and releases their assignments" do
    route = create(:route, company: company, truck: truck, trailer: trailer, route_date: date)
    event = create(:service_event, :service, order: nil, route: route, scheduled_on: date)

    result = described_class.new(company: company, date: date).call

    expect(result).to be_success
    expect(result.routes_cleared).to eq(1)
    expect(result.events_released).to eq(1)
    expect(Route.exists?(route.id)).to be(false)
    expect(RouteStop.exists?(service_event_id: event.id)).to be(false)
  end

  it "refuses to clear when completed events are assigned on that day" do
    route = create(:route, company: company, truck: truck, trailer: trailer, route_date: date)
    completed_event = create(:service_event, :service, :completed, order: nil, route: route, scheduled_on: date)

    result = described_class.new(company: company, date: date).call

    expect(result).not_to be_success
    expect(result.error).to include("completed events")
    expect(Route.exists?(route.id)).to be(true)
    expect(RouteStop.exists?(route_id: route.id, service_event_id: completed_event.id)).to be(true)
  end
end
