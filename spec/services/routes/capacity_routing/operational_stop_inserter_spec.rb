require "rails_helper"

RSpec.describe Routes::CapacityRouting::OperationalStopInserter do
  let(:company) { create(:company, :with_home_base, dump_threshold_percent: 85) }
  let!(:dump_site) { create(:dump_site, company: company, location: create(:location, :standalone, lat: 43.2, lng: -90.3)) }
  let(:truck) { create(:truck, company: company, waste_capacity_gal: 100, clean_water_capacity_gal: 100) }
  let(:trailer) { create(:trailer, company: company, capacity_spots: 4) }
  let(:config) { Routes::CapacityRouting::TruckConfig.new(truck: truck, trailer: trailer, company: company) }
  let(:distance_lookup) { Routes::CapacityRouting::DistanceLookup.new(company: company) }
  let(:user) { create(:user, company: company) }
  let(:customer) { create(:customer, company: company) }
  let(:location) { create(:location, customer: customer, lat: 43.5, lng: -90.5) }
  let(:order) { create(:order, company: company, customer: customer, location: location, created_by: user, status: "scheduled") }
  let(:unit_type) { create(:unit_type, :standard, company: company) }
  let(:rate_plan) { create(:rate_plan, company: company, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:none]) }

  before do
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 1, service_schedule: "none", billing_period: "monthly")
  end

  it "inserts a dump stop when projected waste exceeds capacity" do
    state = Routes::CapacityRouting::RouteState.new(waste_gal: 95, clean_water_gal: 100, current_position: company.home_base)
    stop = create(:service_event, :service, order: order)

    result = described_class.new(state, stop, config, remaining_stops: [], distance_lookup: distance_lookup).call

    expect(result.operational_stops.map { |s| s[:type] }).to include(:dump)
    expect(result.terminate_route).to be(false)
  end

  it "terminates route with home base refill when water would go below reserve" do
    state = Routes::CapacityRouting::RouteState.new(waste_gal: 0, clean_water_gal: 1, current_position: company.home_base)
    stop = create(:service_event, :service, order: order)

    result = described_class.new(state, stop, config, remaining_stops: [], distance_lookup: distance_lookup).call

    expect(result.terminate_route).to be(true)
    expect(result.operational_stops).to include(include(type: :home_base, reason: :refill))
  end

  it "returns hard planner errors for delivery inventory shortfall" do
    state = Routes::CapacityRouting::RouteState.new(waste_gal: 0, clean_water_gal: 100, current_position: company.home_base, trailer_inventory: {})
    stop = create(:service_event, :delivery, order: order)

    result = described_class.new(state, stop, config, remaining_stops: [], distance_lookup: distance_lookup).call

    expect(result.errors).to include(include(type: "delivery_inventory_shortfall", stop_id: stop.id, missing_unit_type: "standard"))
  end
end
