require "rails_helper"

RSpec.describe RouteStop do
  it "enforces one route stop per service event across routes" do
    route_one = create(:route)
    route_two = create(:route, company: route_one.company)
    event = create(:service_event, :service, order: nil, scheduled_on: route_one.route_date)

    create(:route_stop, route: route_one, service_event: event, position: 0)
    duplicate = build(:route_stop, route: route_two, service_event: event, position: 0)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:service_event_id]).to include("has already been taken")
  end

  it "enforces unique position within a route" do
    route = create(:route)
    event_one = create(:service_event, :service, order: nil, scheduled_on: route.route_date)
    event_two = create(:service_event, :service, order: nil, scheduled_on: route.route_date)

    create(:route_stop, route: route, service_event: event_one, position: 0)
    duplicate_position = build(:route_stop, route: route, service_event: event_two, position: 0)

    expect(duplicate_position).not_to be_valid
    expect(duplicate_position.errors[:position]).to include("has already been taken")
  end
end
