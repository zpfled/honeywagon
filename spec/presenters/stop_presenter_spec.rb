require 'rails_helper'

RSpec.describe StopPresenter do
  let(:order) { create(:order) }
  let(:dump_site) { create(:dump_site) }
  let(:event) { create(:service_event, :delivery, order: order, route_sequence: 0, drive_distance_meters: 1609.34) }
  let(:capacity_step) do
    instance_double(
      Routes::Optimization::CapacitySimulator::Step,
      waste_used: 10, waste_capacity: 20,
      clean_used: 5, clean_capacity: 10,
      trailer_used: 1, trailer_capacity: 2,
      violations: [ { message: 'Over waste' } ]
    )
  end
  let(:presenter) { described_class.new(event, capacity_step: capacity_step) }

  it 'exposes stop number and leg distance' do
    expect(presenter.stop_number).to eq(1)
    allow(event).to receive(:humanized_leg_drive_distance).and_return('1.0 mi')
    expect(presenter.leg_distance).to eq('1.0 mi')
  end

  it 'formats fuel cost when present' do
    allow(event).to receive(:estimated_fuel_cost_cents).and_return(1234)
    expect(presenter.fuel_cost).to include('12.34')
  end

  it 'exposes order and dump info' do
    expect(presenter.order_customer_name).to eq(order.customer.display_name)
    expect(presenter.order_customer_email).to eq(order.customer.billing_email)
    expect(presenter.order_location_label).to eq(order.location.label)
    expect(presenter.order_city_state).to eq([ order.location.city, order.location.state ].compact.join(', '))
    expect(presenter.order_date_range).to include(I18n.l(order.start_date))
  end

  it 'handles dump events' do
    dump_event = create(:service_event, :dump, dump_site: dump_site, route_sequence: nil)
    dump_presenter = described_class.new(dump_event)
    expect(dump_presenter.dump_site_name).to eq(dump_site.name)
    expect(dump_presenter.dump_site_location_label).to eq(dump_site.location.display_label)
  end

  it 'handles refill events' do
    company = create(:company, :with_home_base)
    route = create(:route, company: company)
    refill_event = create(:service_event, :refill, route: route, scheduled_on: route.route_date)
    refill_presenter = described_class.new(refill_event)
    expect(refill_presenter.refill_location_label).to eq(company.home_base.display_label)
  end

  it 'builds capacity usage rows and violations' do
    rows = presenter.capacity_usage_rows
    expect(rows.map { |r| r[:label] }).to include('Waste 10/20', 'Clean 5/10', 'Trailer 1/2')
    expect(presenter.capacity_violations).to include('Over waste')
  end

  it 'exposes completion and move flags' do
    allow(event).to receive(:status_completed?).and_return(true)
    expect(presenter.completed?).to be(true)
    expect(presenter.disable_move_later?).to be(true)
    expect(presenter.disable_move_earlier?).to be(true)
  end
end
