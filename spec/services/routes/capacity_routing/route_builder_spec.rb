require "rails_helper"

RSpec.describe Routes::CapacityRouting::RouteBuilder do
  it "reorders stops before a dump to move toward the dump site" do
    company = create(:company, :with_home_base)
    create(:trailer, company: company, capacity_spots: 2, preference_rank: 1)
    create(:truck, company: company, clean_water_capacity_gal: 100, waste_capacity_gal: 100, preference_rank: 1)

    dump_site = create(:dump_site, company: company, location: create(:location, lat: 45.0, lng: -90.0))
    customer = create(:customer, company: company)

    far_location = create(:location, customer: customer, lat: 45.5, lng: -90.5)
    near_location = create(:location, customer: customer, lat: 45.01, lng: -90.01)

    far_order = create(:order, company: company, customer: customer, location: far_location)
    near_order = create(:order, company: company, customer: customer, location: near_location)

    far_event = create(:service_event, :service, order: far_order, scheduled_on: Date.current)
    near_event = create(:service_event, :service, order: near_order, scheduled_on: Date.current)

    builder = described_class.new(company: company, start_date: Date.current, candidates: [])
    stops = [ near_event, far_event, { type: :dump, location: dump_site.location, dump_site: dump_site } ]

    reordered = builder.send(:reorder_for_dump, stops)

    expect(reordered[0]).to eq(far_event)
    expect(reordered[1]).to eq(near_event)
  end
end
