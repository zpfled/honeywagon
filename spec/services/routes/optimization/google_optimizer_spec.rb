require 'rails_helper'

RSpec.describe Routes::Optimization::GoogleOptimizer do
  let(:company) { create(:company, :with_home_base) }
  let(:route) { create(:route, company: company) }

  def create_order_with_location(lat:, lng:)
    customer = create(:customer, company: company)
    location = create(:location, customer: customer, lat: lat, lng: lng)
    create(:order, company: company, location: location, customer: customer)
  end

  describe '#call' do
    it 'returns current ordering and simulation when every stop has coordinates' do
      order = create_order_with_location(lat: 43.0, lng: -90.0)
      event = create(:service_event, :service, order: order, route: route)

      # Stub the client to avoid hitting Google during specs
      fake_client = instance_double(Routes::Optimization::GoogleRoutesClient)
      allow(Routes::Optimization::GoogleRoutesClient).to receive(:new).and_return(fake_client)
      allow(fake_client).to receive(:optimize).and_return(
        Routes::Optimization::GoogleRoutesClient::Result.new(
          success?: true,
          event_ids_in_order: [ event.id ],
          warnings: [],
          errors: [],
          total_distance_meters: 1000,
          total_duration_seconds: 600
        )
      )

      result = described_class.call(route)

      expect(result.errors).to be_empty
      expect(result.event_ids_in_order).to eq([ event.id ])
      expect(result.simulation).to be_present
    end

    it 'returns an error when a stop lacks coordinates' do
      customer = create(:customer, company: company)
      location = create(:location, customer: customer, lat: nil, lng: nil)
      order = create(:order, company: company, location: location, customer: customer)
      create(:service_event, :service, order: order, route: route)

      result = described_class.call(route)

      expect(result.errors).not_to be_empty
      expect(result.event_ids_in_order).to be_empty
    end

    it 'fails when the company base location is missing' do
      company.update!(home_base: nil)
      order = create_order_with_location(lat: 43.0, lng: -90.0)
      create(:service_event, :service, order: order, route: route)

      result = described_class.call(route)

      expect(result.errors).to include('Company location is not configured.')
      expect(result.event_ids_in_order).to be_empty
    end

    it 'passes the base location as start/end stops' do
      order = create_order_with_location(lat: 43.0, lng: -90.0)
      event = create(:service_event, :service, order: order, route: route)
      base = company.home_base
      fake_client = instance_double(Routes::Optimization::GoogleRoutesClient)
      allow(Routes::Optimization::GoogleRoutesClient).to receive(:new).and_return(fake_client)

      expect(fake_client).to receive(:optimize) do |stops|
        expect(stops.first).to include(lat: base.lat, lng: base.lng)
        expect(stops.last).to include(lat: base.lat, lng: base.lng)
        expect(stops.map { |s| s[:id] }).to include(event.id)

        Routes::Optimization::GoogleRoutesClient::Result.new(
          success?: true,
          event_ids_in_order: [ nil, event.id, nil ],
          warnings: [],
          errors: [],
          total_distance_meters: 1000,
          total_duration_seconds: 600,
          legs: [ { distance_meters: 10, duration_seconds: 5 }, { distance_meters: 10, duration_seconds: 5 } ]
        )
      end

      result = described_class.call(route)

      expect(result.errors).to be_empty
      expect(result.event_ids_in_order).to eq([ event.id ])
    end
  end
end
