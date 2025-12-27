require 'rails_helper'

RSpec.describe Routes::Optimization::ManualRun do
  let(:company) { create(:company, :with_home_base, fuel_price_per_gal_cents: 300) }
  let(:route) { create(:route, company: company) }

  def create_event(lat:, lng:)
    customer = create(:customer, company: company)
    location = create(:location, customer: customer, lat: lat, lng: lng)
    order = create(:order, company: company, location: location, customer: customer)
    create(:service_event, :service, order: order, route: route, route_date: route.route_date)
  end

  describe '#call' do
    it 'fails when events do not belong to the route' do
      other_event = create(:service_event) # different route
      result = described_class.call(route, [ other_event.id ])

      expect(result).not_to be_success
      expect(result.errors).to include('Some service events are invalid for this route.')
    end

    it 'fails when the company home base is missing' do
      route.company.update!(home_base: nil)
      event = create_event(lat: 1, lng: 1)

      result = described_class.call(route, [ event.id ])

      expect(result).not_to be_success
      expect(result.errors).to include('Company location is not configured.')
    end

    it 'fails when an event is missing coordinates' do
      customer = create(:customer, company: company)
      location = create(:location, customer: customer, lat: nil, lng: nil)
      order = create(:order, company: company, location: location, customer: customer)
      event = create(:service_event, :service, order: order, route: route, route_date: route.route_date)

      result = described_class.call(route, [ event.id ])

      expect(result).not_to be_success
      expect(result.errors.first).to include('missing latitude/longitude')
    end

    it 'calls Google without optimizing waypoints and returns legs' do
      event = create_event(lat: 1, lng: 1)
      base = company.home_base
      fake_client = instance_double(Routes::Optimization::GoogleRoutesClient)
      allow(Routes::Optimization::GoogleRoutesClient).to receive(:new).and_return(fake_client)

      expect(fake_client).to receive(:optimize) do |stops, optimize_waypoint_order:|
        expect(optimize_waypoint_order).to be(false)
        expect(stops.first).to include(lat: base.lat, lng: base.lng)
        expect(stops.last).to include(lat: base.lat, lng: base.lng)
        expect(stops.map { |s| s[:id] }).to include(event.id)

        Routes::Optimization::GoogleRoutesClient::Result.new(
          success?: true,
          event_ids_in_order: [ nil, event.id, nil ],
          warnings: [],
          errors: [],
          total_distance_meters: 5000,
          total_duration_seconds: 600,
          legs: [ { distance_meters: 1000, duration_seconds: 120 }, { distance_meters: 4000, duration_seconds: 480 } ]
        )
      end

      result = described_class.call(route, [ event.id ])

      expect(result).to be_success
      expect(result.legs.length).to eq(2)
      expect(result.total_distance_meters).to eq(5000)
      expect(route.reload.estimated_drive_meters).to eq(5000)
      expect(route.estimated_drive_seconds).to eq(600)
      expect(event.reload.drive_distance_meters).to eq(1000)
      expect(event.drive_duration_seconds).to eq(120)
    end
  end
end
