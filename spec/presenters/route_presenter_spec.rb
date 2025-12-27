require 'rails_helper'

RSpec.describe RoutePresenter do
  let(:route) { build_stubbed(:route, estimated_drive_seconds: 8100, estimated_drive_meters: 1609.34) }
  let(:presenter) { described_class.new(route) }

  describe '#humanized_drive_time' do
    it 'returns formatted time (happy path)' do
      expect(presenter.humanized_drive_time).to eq('2h 15m')
    end

    it 'returns nil when no estimate (sad/bad path)' do
      allow(route).to receive(:estimated_drive_seconds).and_return(0)
      expect(presenter.humanized_drive_time).to be_nil
    end
  end

  describe '#humanized_drive_distance' do
    it 'returns formatted distance (happy path)' do
      expect(presenter.humanized_drive_distance).to eq('1.0 mi')
    end

    it 'returns nil when no estimate (sad/bad path)' do
      allow(route).to receive(:estimated_drive_meters).and_return(0)
      expect(presenter.humanized_drive_distance).to be_nil
    end
  end
end
