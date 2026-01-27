require "rails_helper"

RSpec.describe Routes::CapacityRouting::Planner do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    Routes::ServiceEventRouter.without_auto_assignment { example.run }
  end

  it "splits routes when trailer capacity would be exceeded" do
    company = create(:company, :with_home_base)
    user = create(:user, company: company)
    trailer = create(:trailer, company: company, capacity_spots: 2, preference_rank: 1)
    truck = create(:truck, company: company, clean_water_capacity_gal: 100, waste_capacity_gal: 100)

    customer = create(:customer, company: company)
    location = create(:location, customer: customer, lat: 44.5, lng: -89.5)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, company: company, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:none])

    order = create(
      :order,
      company: company,
      created_by: user,
      customer: customer,
      location: location,
      status: "scheduled",
      start_date: Date.new(2024, 8, 1),
      end_date: Date.new(2024, 8, 5)
    )
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, service_schedule: RatePlan::SERVICE_SCHEDULES[:none], quantity: 5)

    Orders::ServiceEventGenerator.new(order).call

    result = described_class.call(company: company, start_date: Date.new(2024, 8, 1), horizon_days: 3)
    planned_routes = result.routes

    expect(planned_routes.length).to be >= 2
    expect(planned_routes.flat_map(&:stops).any? { |stop| stop.is_a?(Hash) && stop[:type] == :home_base }).to be(true)
  end

  it "inserts dump stops when the waste threshold would be exceeded" do
    company = create(:company, :with_home_base)
    create(:dump_site, company: company)
    user = create(:user, company: company)
    create(:trailer, company: company, capacity_spots: 10, preference_rank: 1)
    create(:truck, company: company, clean_water_capacity_gal: 100, waste_capacity_gal: 100, preference_rank: 1)

    customer = create(:customer, company: company)
    location = create(:location, customer: customer, lat: 44.5, lng: -89.5)
    unit_type = create(:unit_type, :standard, company: company, service_waste_gallons: 10)
    rate_plan = create(:rate_plan, company: company, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:none])

    order = create(
      :order,
      company: company,
      created_by: user,
      customer: customer,
      location: location,
      status: "scheduled",
      start_date: Date.new(2024, 8, 1),
      end_date: Date.new(2024, 8, 5)
    )
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, service_schedule: RatePlan::SERVICE_SCHEDULES[:none], quantity: 6)

    create(:service_event, :service, order: order, scheduled_on: Date.new(2024, 8, 1))
    create(:service_event, :service, order: order, scheduled_on: Date.new(2024, 8, 2))

    result = described_class.call(company: company, start_date: Date.new(2024, 8, 1), horizon_days: 3)
    stops = result.routes.flat_map(&:stops)

    expect(stops.any? { |stop| stop.is_a?(Hash) && stop[:type] == :dump }).to be(true)
  end

  it "inserts a reload before a pickup that would exceed trailer capacity" do
    company = create(:company, :with_home_base)
    user = create(:user, company: company)
    create(:trailer, company: company, capacity_spots: 2, preference_rank: 1)
    create(:truck, company: company, clean_water_capacity_gal: 100, waste_capacity_gal: 100, preference_rank: 1)

    customer = create(:customer, company: company)
    location = create(:location, customer: customer, lat: 44.5, lng: -89.5)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, company: company, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:none])

    order_small = create(
      :order,
      company: company,
      created_by: user,
      customer: customer,
      location: location,
      status: "scheduled",
      start_date: Date.new(2024, 8, 1),
      end_date: Date.new(2024, 8, 5)
    )
    create(:rental_line_item, order: order_small, unit_type: unit_type, rate_plan: rate_plan, service_schedule: RatePlan::SERVICE_SCHEDULES[:none], quantity: 1)

    order_large = create(
      :order,
      company: company,
      created_by: user,
      customer: customer,
      location: location,
      status: "scheduled",
      start_date: Date.new(2024, 8, 1),
      end_date: Date.new(2024, 8, 5)
    )
    create(:rental_line_item, order: order_large, unit_type: unit_type, rate_plan: rate_plan, service_schedule: RatePlan::SERVICE_SCHEDULES[:none], quantity: 2)

    pickup_small = create(:service_event, :pickup, order: order_small, scheduled_on: Date.new(2024, 8, 1))
    pickup_large = create(:service_event, :pickup, order: order_large, scheduled_on: Date.new(2024, 8, 2))

    result = described_class.call(company: company, start_date: Date.new(2024, 8, 1), horizon_days: 3)
    routes = result.routes

    route_with_small = routes.find { |route| route.stops.include?(pickup_small) }
    route_with_large = routes.find { |route| route.stops.include?(pickup_large) }

    expect(route_with_small).not_to be_nil
    expect(route_with_large).not_to be_nil
    expect(route_with_small).not_to eq(route_with_large)
    last_stop = route_with_small.stops.last
    expect(last_stop).to be_a(Hash)
    expect(last_stop[:type]).to eq(:home_base)
  end

  it "excludes events from cancelled orders" do
    company = create(:company, :with_home_base)
    user = create(:user, company: company)
    create(:trailer, company: company, capacity_spots: 2, preference_rank: 1)
    create(:truck, company: company, clean_water_capacity_gal: 100, waste_capacity_gal: 100, preference_rank: 1)

    customer = create(:customer, company: company)
    location = create(:location, customer: customer, lat: 44.5, lng: -89.5)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, company: company, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:none])

    cancelled_order = create(
      :order,
      company: company,
      created_by: user,
      customer: customer,
      location: location,
      status: "cancelled",
      start_date: Date.new(2024, 8, 1),
      end_date: Date.new(2024, 8, 5)
    )
    create(:rental_line_item, order: cancelled_order, unit_type: unit_type, rate_plan: rate_plan, service_schedule: RatePlan::SERVICE_SCHEDULES[:none], quantity: 1)
    cancelled_event = create(:service_event, :service, order: cancelled_order, scheduled_on: Date.new(2024, 8, 2))

    active_order = create(
      :order,
      company: company,
      created_by: user,
      customer: customer,
      location: location,
      status: "active",
      start_date: Date.new(2024, 8, 1),
      end_date: Date.new(2024, 8, 5)
    )
    create(:rental_line_item, order: active_order, unit_type: unit_type, rate_plan: rate_plan, service_schedule: RatePlan::SERVICE_SCHEDULES[:none], quantity: 1)
    active_event = create(:service_event, :service, order: active_order, scheduled_on: Date.new(2024, 8, 2))

    result = described_class.call(company: company, start_date: Date.new(2024, 8, 1), horizon_days: 3)
    stops = result.routes.flat_map(&:stops)

    expect(stops).to include(active_event)
    expect(stops).not_to include(cancelled_event)
  end
end
