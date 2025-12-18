require "rails_helper"

RSpec.describe Routes::ServiceEventMover do
  let(:company) { create(:company) }
  let!(:truck) { create(:truck, company: company) }
  let!(:trailer) { create(:trailer, company: company) }
  let!(:route) { create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current) }
  let!(:order) do
    create(:order,
           company: company,
           status: "scheduled",
           start_date: Date.current,
           end_date: Date.current + 2.days)
  end

  it "refuses to postpone delivery events" do
    event = create(:service_event, :delivery, order: order, route: route, route_date: route.route_date, scheduled_on: order.start_date)

    result = described_class.new(event).move_to_next

    expect(result).not_to be_success
    expect(result.message).to include("scheduled dates")
  end

  it "refuses to move pickups earlier" do
    pickup_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: order.end_date)
    event = create(:service_event, :pickup, order: order, route: pickup_route, route_date: pickup_route.route_date, scheduled_on: order.end_date)

    result = described_class.new(event).move_to_previous

    expect(result).not_to be_success
    expect(result.message).to include("scheduled dates")
  end
end
