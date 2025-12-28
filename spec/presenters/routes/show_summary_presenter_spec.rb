require 'rails_helper'

RSpec.describe Routes::ShowSummaryPresenter do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company, waste_capacity_gal: 100, clean_water_capacity_gal: 50) }
  let(:trailer) { create(:trailer, company: company, capacity_spots: 10) }
  let(:route) { create(:route, company: company, truck: truck, trailer: trailer, estimated_drive_seconds: 3600, estimated_drive_meters: 1609.34) }
  let(:waste_load) { { cumulative_used: 20, capacity: 100 } }
  let(:presenter) { described_class.new(route: route, waste_load: waste_load) }

  it 'exposes capacity usage' do
    expect(presenter.trailer_usage[:capacity]).to eq(trailer.capacity_spots)
    expect(presenter.clean_usage[:capacity]).to eq(truck.clean_water_capacity_gal)
    expect(presenter.waste_usage[:capacity]).to eq(truck.waste_capacity_gal)
  end

  it 'returns waste summary using provided load' do
    summary = presenter.waste_summary
    expect(summary[:cumulative_used]).to eq(20)
    expect(summary[:capacity]).to eq(100)
  end

  it 'returns drive metrics and stale flag' do
    expect(presenter.drive_time).to eq('1h 0m')
    expect(presenter.drive_distance).to be_present
    allow(route).to receive(:optimization_stale?).and_return(true)
    expect(presenter.optimization_stale?).to be(true)
  end

  it 'formats labels for truck and trailer' do
    expect(presenter.truck_label).to eq(route.truck.label)
    expect(presenter.trailer_label).to eq(route.trailer.label)
  end
end
