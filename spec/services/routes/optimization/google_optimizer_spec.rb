require 'rails_helper'

RSpec.describe Routes::Optimization::GoogleOptimizer do
  let(:company) { create(:company) }
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
  end
end
