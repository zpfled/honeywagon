require 'rails_helper'

RSpec.describe Routes::Optimization::Run do
  let(:route) { create(:route) }

  it 'returns optimizer result fields' do
    fake_result = Routes::Optimization::GoogleOptimizer::Result.new(
      event_ids_in_order: [ 'event-id' ],
      warnings: [ 'warn' ],
      errors: [],
      simulation: double(:simulation),
      total_distance_meters: 1000,
      total_duration_seconds: 600
    )
    allow(Routes::Optimization::GoogleOptimizer).to receive(:call).and_return(fake_result)

    result = described_class.call(route)

    expect(result).to be_success
    expect(result.event_ids_in_order).to eq([ 'event-id' ])
    expect(result.warnings).to include('warn')
    expect(result.errors).to be_empty
    expect(result.simulation).to eq(fake_result.simulation)
    expect(result.distance_meters).to eq(1000)
    expect(result.duration_seconds).to eq(600)
  end

  it 'reports failure when optimizer returns errors' do
    fake_result = Routes::Optimization::GoogleOptimizer::Result.new(
      event_ids_in_order: [],
      warnings: [],
      errors: [ 'missing coords' ],
      simulation: nil,
      total_distance_meters: 0,
      total_duration_seconds: 0
    )
    allow(Routes::Optimization::GoogleOptimizer).to receive(:call).and_return(fake_result)

    result = described_class.call(route)

    expect(result).not_to be_success
    expect(result.errors).to eq([ 'missing coords' ])
  end
end
