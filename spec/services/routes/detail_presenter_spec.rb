require 'rails_helper'

RSpec.describe Routes::DetailPresenter do
  it 'exposes service events and previous/next routes' do
    company = create(:company)
    previous_route = create(:route, company: company, route_date: Date.current - 1)
    current_route = create(:route, company: company, route_date: Date.current)
    next_route = create(:route, company: company, route_date: Date.current + 1)
    event = create(:service_event, route: current_route)

    presenter = described_class.new(current_route, company: company)

    expect(presenter.service_events).to include(event)
    expect(presenter.previous_route).to eq(previous_route)
    expect(presenter.next_route).to eq(next_route)
  end
end
