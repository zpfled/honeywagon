require "rails_helper"

RSpec.describe Routes::CapacityRouting::ResourceDeltaCalculator do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:customer) { create(:customer, company: company) }
  let(:location) { create(:location, customer: customer) }
  let(:order) do
    create(:order, company: company, created_by: user, customer: customer, location: location, status: "scheduled")
  end

  it "uses service_event_units when present" do
    unit_type = create(:unit_type, :standard, company: company, service_clean_gallons: 7, service_waste_gallons: 10)
    event = create(:service_event, :service, order: order)
    event.service_event_units.create!(unit_type: unit_type, quantity: 2)

    result = described_class.new(event, :service).call

    expect(result.clean_water_gal).to eq(-14.0)
    expect(result.dirty_water_gal).to eq(20.0)
    expect(result.units_by_slug[:standard]).to eq(2)
  end

  it "falls back to rental line items when service_event_units are absent" do
    unit_type = create(:unit_type, :standard, company: company, pickup_clean_gallons: 2, pickup_waste_gallons: 10)
    rate_plan = create(:rate_plan, company: company, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:none])
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 3, service_schedule: "none", billing_period: "monthly")
    event = create(:service_event, :pickup, order: order)

    result = described_class.new(event, :pickup).call

    expect(result.clean_water_gal).to eq(-6.0)
    expect(result.dirty_water_gal).to eq(30.0)
    expect(result.units_by_slug[:standard]).to eq(3)
  end
end
