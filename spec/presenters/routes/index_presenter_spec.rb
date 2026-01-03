require 'rails_helper'

RSpec.describe Routes::IndexPresenter do
  describe '#rows' do
    it 'wraps each route in a row presenter' do
      routes = create_list(:route, 2)

      presenter = described_class.new(routes)

      expect(presenter.rows.map(&:route)).to match_array(routes)
    end
  end

  describe Routes::IndexPresenter::Row do
    let(:route) { create(:route) }

    def build_event(type, gallons:)
      create(:service_event, type, route: route)
    end

    before do
      allow(ServiceEvents::GallonsEstimator).to receive(:call).and_return(10, 5, 0)
      build_event(:delivery, gallons: 10)
      build_event(:service, gallons: 5)
      build_event(:pickup, gallons: 0)
    end

    let(:row) { described_class.new(route) }

    it 'returns the underlying route' do
      expect(row.route).to eq(route)
    end

    it 'counts all service events' do
      expect(row.service_event_count).to eq(3)
    end

    it 'counts deliveries' do
      expect(row.deliveries_count).to eq(1)
    end

    it 'counts services' do
      expect(row.services_count).to eq(1)
    end

    it 'counts pickups' do
      expect(row.pickups_count).to eq(1)
    end

    it 'sums estimated gallons' do
      expect(row.estimated_gallons).to eq(15)
    end

    it 'delegates capacity checks to the route' do
      allow(route).to receive(:over_capacity?).and_return(true)
      allow(route).to receive(:over_capacity_dimensions).and_return([ :waste, :trailer ])

      expect(row.over_capacity?).to be(true)
      expect(row.over_capacity_dimensions).to eq([ :waste, :trailer ])
    end
  end
end
