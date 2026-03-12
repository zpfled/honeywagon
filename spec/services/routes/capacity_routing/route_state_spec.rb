require "rails_helper"

RSpec.describe Routes::CapacityRouting::RouteState do
  let(:company) { create(:company, :with_home_base) }
  let(:truck) { create(:truck, company: company, clean_water_capacity_gal: 100, waste_capacity_gal: 300) }
  let(:trailer) { create(:trailer, company: company, capacity_spots: 10) }
  let(:config) { Routes::CapacityRouting::TruckConfig.new(truck: truck, trailer: trailer, company: company) }
  let(:customer) { create(:customer, company: company) }
  let(:location) { create(:location, customer: customer, lat: 43.1, lng: -90.2) }
  let(:order) { create(:order, company: company, customer: customer, location: location, created_by: create(:user, company: company), status: "scheduled") }

  it "applies event deltas and updates position" do
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, company: company, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:none])
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 2, service_schedule: "none", billing_period: "monthly")
    event = create(:service_event, :service, order: order)

    state = described_class.new(waste_gal: 0, clean_water_gal: 100, current_position: company.home_base)
    state.apply_stop!(event, config)

    expect(state.waste_gal).to eq(20.0)
    expect(state.clean_water_gal).to eq(86.0)
    expect(state.current_position).to eq(location)
  end

  it "resets state for dump and refill operational stops" do
    state = described_class.new(waste_gal: 120, clean_water_gal: 20, current_position: company.home_base)

    state.apply_stop!({ type: :dump, location: company.home_base }, config)
    expect(state.waste_gal).to eq(0.0)

    state.apply_stop!({ type: :home_base, reason: :refill, location: company.home_base }, config)
    expect(state.clean_water_gal).to eq(100.0)
  end

  it "computes trailer spaces with handwash nesting" do
    state = described_class.new(
      waste_gal: 0,
      clean_water_gal: 100,
      current_position: company.home_base,
      trailer_inventory: { standard: 1, ada: 1, handwash: 3 }
    )

    expect(state.trailer_spaces_used).to eq(5)
  end
end
