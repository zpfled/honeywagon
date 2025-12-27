require 'rails_helper'

# TODO: Flesh out StopPresenter specs for per-stop formatting once defined.
RSpec.describe StopPresenter do
  it 'is initialized with a service event' do
    event = build_stubbed(:service_event)
    presenter = described_class.new(event)
    expect(presenter).to be_present
  end
end
