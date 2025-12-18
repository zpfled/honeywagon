require 'rails_helper'

RSpec.describe Routes::DetailPresenter do
  it 'exposes service events and previous/next routes' do
    company = create(:company)
    previous_route = create(:route, company: company, route_date: Date.current - 1)
    current_route = create(:route, company: company, route_date: Date.current)
    next_route = create(:route, company: company, route_date: Date.current + 1)
    event = create(:service_event, route: current_route)

    presenter = described_class.new(current_route, company: company)

    expect(presenter.service_events).to include(event)
    expect(presenter.previous_route).to eq(previous_route)
    expect(presenter.next_route).to eq(next_route)
  end
end

RSpec.describe Routes::DetailPresenter, '#septage_load' do
  it 'returns cumulative septage usage for the truck up to the route' do
    company = create(:company)
    truck = create(:truck, company: company, septage_capacity_gal: 200)
    create(:trailer, company: company)
    order = create(:order, company: company)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, unit_type: unit_type)
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 2)

    route1 = create(:route, company: company, truck: truck, route_date: Date.current - 1)
    create(:service_event, :service, order: order, route: route1, route_date: route1.route_date)

    route2 = create(:route, company: company, truck: truck, route_date: Date.current)
    create(:service_event, :service, order: order, route: route2, route_date: route2.route_date)

    presenter = described_class.new(route2, company: company)
    load = presenter.septage_load

    expect(load[:cumulative_used]).to be > 0
    expect(load[:capacity]).to eq(truck.septage_capacity_gal)
  end
end
