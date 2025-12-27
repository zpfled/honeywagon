require 'rails_helper'

# TODO: Flesh out StopPresenter specs for per-stop formatting once defined.
RSpec.describe StopPresenter do
  let(:event) { build_stubbed(:service_event, route_sequence: 0, drive_distance_meters: 1609.34) }
  let(:presenter) { described_class.new(event) }

  it 'exposes stop number and leg distance' do
    expect(presenter.stop_number).to eq(1)
    allow(event).to receive(:humanized_leg_drive_distance).and_return('1.0 mi')
    expect(presenter.leg_distance).to eq('1.0 mi')
  end
end
