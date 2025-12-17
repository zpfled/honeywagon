require 'rails_helper'

RSpec.describe Routes::SeptageTracker do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company, septage_capacity_gal: 100) }
  let(:other_truck) { create(:truck, company: company, septage_capacity_gal: 50) }
  let(:trailer) { create(:trailer, company: company) }

  def create_route_with_usage(truck:, route_date:, gallons:)
    route = create(:route, company: company, truck: truck, trailer: trailer, route_date: route_date)
    order = create(:order, company: company)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, unit_type: unit_type)
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: gallons / 10)
    create(:service_event, :service, order: order, route: route, route_date: route.route_date)
    route
  end

  it 'tracks cumulative septage usage per truck' do
    route1 = create_route_with_usage(truck: truck, route_date: Date.current, gallons: 20)
    route2 = create_route_with_usage(truck: truck, route_date: Date.current + 1, gallons: 30)
    route3 = create_route_with_usage(truck: other_truck, route_date: Date.current, gallons: 40)

    tracker = described_class.new([ route1, route2, route3 ])
    loads = tracker.loads_by_route_id

    expect(loads[route1.id][:cumulative_used]).to eq(20)
    expect(loads[route1.id][:over_capacity]).to be(false)

    expect(loads[route2.id][:cumulative_used]).to eq(50)
    expect(loads[route2.id][:over_capacity]).to be(false)

    expect(loads[route3.id][:cumulative_used]).to eq(40)
    expect(loads[route3.id][:capacity]).to eq(50)
  end
end
