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

  it 'resets clean water usage when encountering a refill event' do
    order = create_order_with_units(quantity: 1)
    service_event = create(:service_event, :service, order: order, route: route)
    refill_event = create(:service_event, :refill, route: route)

    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(service_event).and_return(
      double(usage: { waste_gallons: 0, clean_water_gallons: 15, trailer_spots: 0 })
    )
    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(refill_event).and_return(
      double(usage: { waste_gallons: 0, clean_water_gallons: 0, trailer_spots: 0 })
    )

    result = described_class.call(route: route, ordered_event_ids: [ service_event.id, refill_event.id ])

    expect(result.steps.last.clean_used).to eq(0)
  end

  it 'does not reset clean water usage based on per-event route_date' do
    order = create_order_with_units(quantity: 1)
    first_event = create(:service_event, :service, order: order, route: route, route_date: Date.current)
    second_event = create(:service_event, :service, order: order, route: route, route_date: Date.current + 1.day)

    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(first_event).and_return(
      double(usage: { waste_gallons: 0, clean_water_gallons: 15, trailer_spots: 0 })
    )
    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(second_event).and_return(
      double(usage: { waste_gallons: 0, clean_water_gallons: 10, trailer_spots: 0 })
    )

    result = described_class.call(route: route, ordered_event_ids: [ first_event.id, second_event.id ])

    expect(result.steps.last.clean_used).to eq(25)
  end

  it 'releases trailer spots on deliveries and consumes them on pickups' do
    delivery = create(:service_event, :delivery, order: create_order_with_units(quantity: 1), route: route)
    pickup = create(:service_event, :pickup, order: create_order_with_units(quantity: 2), route: route)

    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(delivery).and_return(
      double(usage: { waste_gallons: 0, clean_water_gallons: 0, trailer_spots: 1 })
    )
    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(pickup).and_return(
      double(usage: { waste_gallons: 0, clean_water_gallons: 0, trailer_spots: 2 })
    )

    result = described_class.call(route: route, ordered_event_ids: [ delivery.id, pickup.id ])

    expect(result.steps.first.trailer_used).to eq(1)
    expect(result.steps.last.trailer_used).to eq(2)
  end

  it 'ignores skipped events when calculating usage' do
    order = create_order_with_units(quantity: 2)
    scheduled_event = create(:service_event, :service, order: order, route: route)
    skipped_event = create(
      :service_event,
      :service,
      order: order,
      route: route,
      status: :skipped,
      skipped_on: Date.current,
      skip_reason: 'Locked gate'
    )

    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(scheduled_event).and_return(
      double(usage: { waste_gallons: 10, clean_water_gallons: 0, trailer_spots: 0 })
    )
    allow(ServiceEvents::ResourceCalculator).to receive(:new).with(skipped_event).and_return(
      double(usage: { waste_gallons: 999, clean_water_gallons: 999, trailer_spots: 999 })
    )

    result = described_class.call(route: route, ordered_event_ids: [ scheduled_event.id, skipped_event.id ])

    expect(result.steps.size).to eq(1)
    expect(result.steps.first.waste_used).to eq(10)
  end
end
