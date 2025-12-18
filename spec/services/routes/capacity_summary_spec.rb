require 'rails_helper'

RSpec.describe Routes::CapacitySummary do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company, clean_water_capacity_gal: 40, septage_capacity_gal: 45) }
  let(:trailer) { create(:trailer, company: company, capacity_spots: 4) }
  let(:route) { create(:route, company: company, truck: truck, trailer: trailer) }
  let(:order) { create(:order, company: company) }
  let(:standard_type) { create(:unit_type, :standard, company: company) }
  let(:rate_plan) { create(:rate_plan, unit_type: standard_type) }

  before do
    create(:rental_line_item, order: order, unit_type: standard_type, rate_plan: rate_plan, quantity: 6)
    create(:service_event, :delivery, order: order, route: route, route_date: route.route_date)
    create(:service_event, :service, order: order, route: route, route_date: route.route_date)
  end

  it 'aggregates usage and detects overages' do
    summary = described_class.new(route: route)

    expect(summary.trailer_usage[:used]).to be > summary.trailer_usage[:capacity]
    expect(summary.clean_water_usage[:used]).to be > summary.clean_water_usage[:capacity]
    expect(summary.septage_usage[:used]).to be > summary.septage_usage[:capacity]
    expect(summary.over_capacity?).to be(true)
    expect(summary.over_capacity_dimensions).to match_array(%i[trailer clean_water septage])
  end

  it 'ignores completed events when calculating usage' do
    route.service_events.update_all(status: ServiceEvent.statuses[:completed])

    summary = described_class.new(route: route)

    expect(summary.trailer_usage[:used]).to eq(0)
    expect(summary.clean_water_usage[:used]).to eq(0)
    expect(summary.septage_usage[:used]).to eq(0)
    expect(summary.over_capacity?).to be(false)
  end
end
