require 'rails_helper'

RSpec.describe Routes::Optimization::CapacitySimulator do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company, clean_water_capacity_gal: 40, waste_capacity_gal: 30) }
  let(:trailer) { create(:trailer, company: company, capacity_spots: 4) }
  let(:route) { create(:route, company: company, truck: truck, trailer: trailer) }

  def create_order_with_units(quantity:)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, unit_type: unit_type)
    order = create(:order, company: company)
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: quantity)
    order
  end

  it 'records steps and violations when usage exceeds capacity' do
    order = create_order_with_units(quantity: 4) # 40 gallons of waste
    event = create(:service_event, :service, order: order, route: route)

    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(event).and_return(
      double(usage: { waste_gallons: 40, clean_water_gallons: 0, trailer_spots: 0 })
    )

    result = described_class.call(route: route, ordered_event_ids: [ event.id ])

    expect(result.steps.size).to eq(1)
    expect(result.violations).to include(a_string_matching(/Waste capacity exceeded/))
  end

  it 'resets waste usage when encountering a dump event' do
    order = create_order_with_units(quantity: 3)
    service_event = create(:service_event, :service, order: order, route: route)
    dump_site = create(:dump_site, company: company)
    dump_event = create(:service_event, :dump, route: route, dump_site: dump_site)

    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(service_event).and_return(
      double(usage: { waste_gallons: 40, clean_water_gallons: 0, trailer_spots: 0 })
    )
    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(dump_event).and_return(
      double(usage: { waste_gallons: 0, clean_water_gallons: 0, trailer_spots: 0 })
    )

    result = described_class.call(route: route, ordered_event_ids: [ service_event.id, dump_event.id ])

    expect(result.steps.last.waste_used).to eq(0)
  end
end
