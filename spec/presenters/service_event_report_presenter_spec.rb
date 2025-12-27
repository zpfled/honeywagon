require 'rails_helper'

# TODO: Flesh out ServiceEventReportPresenter specs for log formatting once defined.
RSpec.describe ServiceEventReportPresenter do
  let(:report) { build_stubbed(:service_event_report) }
  let(:presenter) { described_class.new(report) }

  it 'exposes basic data' do
    allow(report.service_event).to receive(:updated_at).and_return(Time.zone.parse('2024-01-01 12:00'))
    expect(presenter.customer_name).to be_present
    expect(presenter.address).to be_present
    expect(presenter.gallons).to be_present
    expect(presenter.units_pumped).to be_present
    expect(presenter.time_label).to eq('12:00 PM')
  end
end
