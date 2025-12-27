require 'rails_helper'

# TODO: Flesh out ServiceEventReportPresenter specs for log formatting once defined.
RSpec.describe ServiceEventReportPresenter do
  it 'is initialized with a report' do
    report = build_stubbed(:service_event_report)
    presenter = described_class.new(report)
    expect(presenter).to be_present
  end
end
