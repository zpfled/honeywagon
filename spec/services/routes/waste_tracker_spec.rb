require 'rails_helper'

RSpec.describe Routes::WasteTracker do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company, waste_capacity_gal: 100) }
  let(:other_truck) { create(:truck, company: company, waste_capacity_gal: 50) }
  let(:trailer) { create(:trailer, company: company) }

  def create_route_with_usage(truck:, route_date:, gallons:, status: :scheduled)
    route = create(:route, company: company, truck: truck, trailer: trailer, route_date: route_date)
    order = create(:order, company: company)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, unit_type: unit_type)
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: gallons / 10)
    create(:service_event, :service, order: order, route: route, route_date: route.route_date, status: status)
    route
  end

  it 'tracks cumulative waste usage per truck from completed events before the earliest route' do
    previous_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current - 1)
    previous_order = create(:order, company: company)
    previous_unit_type = create(:unit_type, :standard, company: company)
    previous_plan = create(:rate_plan, unit_type: previous_unit_type)
    create(:rental_line_item, order: previous_order, unit_type: previous_unit_type, rate_plan: previous_plan, quantity: 1)
    create(:service_event, :service, order: previous_order, route: previous_route, route_date: previous_route.route_date, status: :completed)

    other_previous_route = create(:route, company: company, truck: other_truck, trailer: trailer, route_date: Date.current - 1)
    other_order = create(:order, company: company)
    other_unit_type = create(:unit_type, :standard, company: company)
    other_plan = create(:rate_plan, unit_type: other_unit_type)
    create(:rental_line_item, order: other_order, unit_type: other_unit_type, rate_plan: other_plan, quantity: 1)
    create(:service_event, :service, order: other_order, route: other_previous_route, route_date: other_previous_route.route_date, status: :completed)

    route1 = create_route_with_usage(truck: truck, route_date: Date.current, gallons: 20)
    route2 = create_route_with_usage(truck: truck, route_date: Date.current + 1, gallons: 30)
    route3 = create_route_with_usage(truck: other_truck, route_date: Date.current, gallons: 40)

    tracker = described_class.new([ route1, route2, route3 ])
    loads = tracker.ending_loads_by_route_id

    expect(loads[route1.id][:cumulative_used]).to eq(30) # 10 baseline + 20
    expect(loads[route2.id][:cumulative_used]).to eq(60) # 30 + 30
    expect(loads[route3.id][:cumulative_used]).to eq(50) # 10 baseline + 40
  end

  it 'tracks starting waste per route before scheduled usage' do
    prior_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current - 1)
    prior_order = create(:order, company: company)
    prior_unit_type = create(:unit_type, :standard, company: company)
    prior_plan = create(:rate_plan, unit_type: prior_unit_type)
    create(:rental_line_item, order: prior_order, unit_type: prior_unit_type, rate_plan: prior_plan, quantity: 1)
    create(:service_event, :service, order: prior_order, route: prior_route, route_date: prior_route.route_date, status: :completed)

    route1 = create_route_with_usage(truck: truck, route_date: Date.current, gallons: 20)
    route2 = create_route_with_usage(truck: truck, route_date: Date.current + 1, gallons: 30)

    tracker = described_class.new([ route1, route2 ])
    starting = tracker.starting_loads_by_route_id

    expect(starting[route1.id]).to eq(10)
    expect(starting[route2.id]).to eq(30) # 10 + 20
  end

  it 'counts completed events when computing carryover' do
    route1 = create_route_with_usage(truck: truck, route_date: Date.current, gallons: 20, status: :completed)
    route2 = create_route_with_usage(truck: truck, route_date: Date.current + 1, gallons: 10)

    tracker = described_class.new([ route1, route2 ])
    starting = tracker.starting_loads_by_route_id

    expect(starting[route2.id]).to eq(20) # 20 from completed route1
  end

  it 'resets baseline after a completed dump before the first route' do
    prior_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current - 2)
    prior_order = create(:order, company: company)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, unit_type: unit_type)
    create(:rental_line_item, order: prior_order, unit_type: unit_type, rate_plan: rate_plan, quantity: 2)
    create(:service_event, :service, order: prior_order, route: prior_route, route_date: prior_route.route_date, status: :completed)
    create(:service_event, :dump, route: prior_route, route_date: prior_route.route_date, status: :completed)

    later_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current - 1)
    later_order = create(:order, company: company)
    create(:rental_line_item, order: later_order, unit_type: unit_type, rate_plan: rate_plan, quantity: 1)
    create(:service_event, :service, order: later_order, route: later_route, route_date: later_route.route_date, status: :completed)

    current_route = create_route_with_usage(truck: truck, route_date: Date.current, gallons: 10)

    tracker = described_class.new([ current_route ])
    starting = tracker.starting_loads_by_route_id

    expect(starting[current_route.id]).to eq(10) # only usage after the dump carries over
  end
end
