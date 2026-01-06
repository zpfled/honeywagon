require "rails_helper"

RSpec.describe Routes::Optimization::CapacityPlanner do
  let(:company) { create(:company, :with_home_base) }
  let(:route) { create(:route, company: company) }
  let(:unit_type) { create(:unit_type, :standard, company: company) }
  let(:rate_plan) { create(:rate_plan, unit_type: unit_type, company: company) }
  let(:order) { create(:order, company: company) }
  let!(:dump_site) { create(:dump_site, company: company) }
  let!(:user) { create(:user, company: company) }

  before do
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 1)
    create(:service_event, :service, order: order, route: route, scheduled_on: route.route_date)
    create(:service_event, :service, order: order, route: route, scheduled_on: route.route_date)
  end

  it "inserts dump and refill stops when capacities are exceeded" do
    route.truck.update!(clean_water_capacity_gal: 10, waste_capacity_gal: 15)

    result = described_class.call(route: route, ordered_event_ids: route.service_events.pluck(:id))

    expect(result.warnings).to be_empty
    expect(route.service_events.event_type_dump.count).to eq(1)
    expect(route.service_events.event_type_refill.count).to eq(1)
    expect(route.service_events.event_type_dump.first.auto_generated).to be(true)
    expect(route.service_events.event_type_refill.first.auto_generated).to be(true)
  end
end
