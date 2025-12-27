require 'rails_helper'

# TODO: Flesh out RoutePresenter specs once formatting responsibilities are defined.
RSpec.describe RoutePresenter do
  it 'is initialized with a route' do
    route = build_stubbed(:route)
    presenter = described_class.new(route)
    expect(presenter).to be_present
  end
end
