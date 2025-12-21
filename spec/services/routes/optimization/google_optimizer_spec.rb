require 'rails_helper'

RSpec.describe Routes::Optimization::GoogleOptimizer do
  let(:company) { create(:company) }
  let(:route) { create(:route, company: company) }

  def create_order_with_location(lat:, lng:)
    location = create(:location, company: company, lat: lat, lng: lng)
    create(:order, company: company, location: location, customer: create(:customer, company: company))
  end

  describe '#call' do
    it 'returns current ordering when every stop has coordinates' do
      order = create_order_with_location(lat: 43.0, lng: -90.0)
      event = create(:service_event, :service, order: order, route: route)

      result = described_class.call(route)

      expect(result.errors).to be_empty
      expect(result.event_ids_in_order).to eq([ event.id ])
      expect(result.warnings).to include(a_string_matching(/existing ordering/))
    end

    it 'returns an error when a stop lacks coordinates' do
      location = create(:location, company: company, lat: nil, lng: nil)
      order = create(:order, company: company, location: location, customer: create(:customer, company: company))
      create(:service_event, :service, order: order, route: route)

      result = described_class.call(route)

      expect(result.errors).not_to be_empty
      expect(result.event_ids_in_order).to be_empty
    end
  end
end
