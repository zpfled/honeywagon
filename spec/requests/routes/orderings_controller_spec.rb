require 'rails_helper'

RSpec.describe 'Routes::OrderingsController', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }
  let(:route) { create(:route, company: company) }
  let!(:event_one) { create(:service_event, :service, order: nil, scheduled_on: route.route_date) }
  let!(:event_two) { create(:service_event, :service, order: nil, scheduled_on: route.route_date) }
  let!(:event_three) { create(:service_event, :service, order: nil, scheduled_on: route.route_date) }
  let!(:stop_one) { create(:route_stop, route: route, service_event: event_one, position: 0) }
  let!(:stop_two) { create(:route_stop, route: route, service_event: event_two, position: 1) }
  let!(:stop_three) { create(:route_stop, route: route, service_event: event_three, position: 2) }

  before { sign_in user }

  it 'resequences using the capacity planner ordering' do
    manual_result = Routes::Optimization::ManualRun::Result.new(
      success?: true,
      event_ids_in_order: [ event_two.id, event_one.id, event_three.id ],
      warnings: [],
      errors: [],
      total_distance_meters: 0,
      total_duration_seconds: 0,
      legs: []
    )
    allow(Routes::Optimization::ManualRun).to receive(:call).and_return(manual_result)

    patch route_ordering_path(route), params: { event_ids: [ event_two.id, event_one.id, event_three.id ] }

    expect(response).to redirect_to(route_path(route))
    expect(flash[:notice]).to include('Route updated:')
    expect(route.reload.route_stops.order(:position).pluck(:service_event_id)).to eq(
      [ event_two.id, event_one.id, event_three.id ]
    )
  end

  it 'keeps the reordered sequence when route optimization fails' do
    manual_result = Routes::Optimization::ManualRun::Result.new(
      success?: false,
      event_ids_in_order: [],
      warnings: [],
      errors: [ 'Dump site is missing latitude/longitude.' ],
      total_distance_meters: nil,
      total_duration_seconds: nil,
      legs: []
    )
    allow(Routes::Optimization::ManualRun).to receive(:call).and_return(manual_result)

    patch route_ordering_path(route), params: { event_ids: [ event_two.id, event_three.id, event_one.id ] }

    expect(response).to redirect_to(route_path(route))
    expect(flash[:alert]).to include('Route order saved, but optimization skipped')
    expect(route.reload.route_stops.order(:position).pluck(:service_event_id)).to eq(
      [ event_two.id, event_three.id, event_one.id ]
    )
  end
end
