require 'rails_helper'

RSpec.describe Routes::GoogleCalendarPusher do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company, google_calendar_refresh_token: 'refresh') }
  let(:route) { create(:route, company: company, route_date: Date.new(2026, 1, 14)) }

  it 'prefixes event summaries with the stop order' do
    customer = create(:customer, company: company, business_name: 'Donny Schmidt')
    order = create(:order, company: company, customer: customer, location: create(:location, customer: customer))
    pickup = create(:service_event, :pickup, order: order, route: route, route_sequence: 1, scheduled_on: route.route_date)
    dump_site = create(:dump_site, company: company)
    dump = create(:service_event, :dump, route: route, dump_site: dump_site, route_sequence: 2)

    calendar_client = instance_double(Google::CalendarClient)
    allow(Google::CalendarClient).to receive(:new).with(user).and_return(calendar_client)
    allow(calendar_client).to receive(:upsert_event)

    described_class.new(route: route, user: user).call

    expect(calendar_client).to have_received(:upsert_event).with(
      pickup,
      hash_including(summary: "1 - Pickup - #{customer.display_name}")
    )
    expect(calendar_client).to have_received(:upsert_event).with(
      dump,
      hash_including(summary: "2 - Dump - #{dump_site.name}")
    )
  end
end
