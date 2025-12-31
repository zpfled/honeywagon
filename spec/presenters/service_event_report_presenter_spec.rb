require 'rails_helper'

RSpec.describe ServiceEventReportPresenter do
  let(:view_context) { double('view', l: 'January 1, 2024') }

  it 'formats non-dump service reports using customer and location' do
    company = create(:company)
    customer = create(:customer, company: company, business_name: 'Acme')
    location = create(:location, customer: customer, street: '1 Main', city: 'Madison', state: 'WI', zip: '53703')
    order = create(:order, company: company, customer: customer, location: location)
    event = create(:service_event, :service, order: order)
    report = create(:service_event_report, service_event: event, data: {
      'estimated_gallons_pumped' => '120',
      'units_pumped' => '3'
    })
    event.update_column(:updated_at, Time.utc(2024, 1, 1, 15, 30))

    presenter = described_class.new(report, view_context: view_context)

    expect(presenter.customer_name).to eq(customer.display_name)
    expect(presenter.address_label).to eq('1 Main, Madison, WI, 53703')
    expect(presenter.units_serviced_label).to eq('3')
    expect(presenter.estimated_gallons_label).to eq('120')
    expect(presenter.date_label).to eq('January 1, 2024')
    expect(presenter.time_label).to eq('09:30 AM')
  end

  it 'formats dump service reports using dump site details' do
    company = create(:company)
    dump_site = create(:dump_site, company: company)
    event = create(:service_event, :dump, dump_site: dump_site)
    report = create(:service_event_report, service_event: event, data: {
      'estimated_gallons_dumped' => '45'
    })
    event.update_column(:updated_at, Time.utc(2024, 2, 1, 12, 0))

    presenter = described_class.new(report, view_context: view_context)

    expect(presenter.customer_name).to eq(dump_site.name)
    expect(presenter.address_label).to eq(dump_site.location.full_address)
    expect(presenter.units_serviced_label).to eq('—')
    expect(presenter.estimated_gallons_label).to eq('45')
  end
end
