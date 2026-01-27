require 'rails_helper'

RSpec.describe Routes::MergeService do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company) }
  let(:trailer) { create(:trailer, company: company) }

  it 'moves source events onto the target route and appends route sequence' do
    target = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current)
    source = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current + 1)
    order = create(:order, company: company)
    other_order = create(:order, company: company)

    first_event = create(:service_event, :service, order: order, route: target, route_sequence: 0, route_date: target.route_date)
    second_event = create(:service_event, :service, order: other_order, route: source, route_sequence: 0, route_date: source.route_date)

    result = described_class.call(source: source, target: target)

    expect(result.success?).to be(true)
    expect(Route.exists?(source.id)).to be(false)
    expect(second_event.reload.route_id).to eq(target.id)
    expect(second_event.route_date).to eq(target.route_date)
    expect(second_event.route_sequence).to be > first_event.route_sequence
  end

  it 'fails when merging a route into itself' do
    route = create(:route, company: company, truck: truck, trailer: trailer)

    result = described_class.call(source: route, target: route)

    expect(result.success?).to be(false)
  end
end
