require 'rails_helper'

RSpec.describe 'Routes::OptimizationsController', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }
  let(:route) { create(:route, company: company) }

  before { sign_in user }

  describe 'POST /routes/:route_id/optimization' do
    def stub_result(success:, warnings: [], errors: [], event_ids: [], duration: 0, distance: 0)
      Routes::Optimization::Run::Result.new(
        success?: success,
        event_ids_in_order: event_ids,
        warnings: warnings,
        errors: errors,
        simulation: nil,
        distance_meters: distance,
        duration_seconds: duration
      )
    end

    context 'when optimization succeeds' do
      it 'sets a notice and redirects back to the route' do
        allow(Routes::Optimization::Run).to receive(:call)
          .with(instance_of(Route))
          .and_return(stub_result(success: true, warnings: [ 'Simulated warning' ]))

        post route_optimization_path(route)

        expect(response).to redirect_to(route_path(route))
        expect(flash[:notice]).to include('Route optimized')
        expect(flash[:notice]).to include('Simulated warning')
      end

      it 'reorders service events based on the returned sequence' do
        event_a = create(:service_event, :service, order: nil, scheduled_on: route.route_date)
        event_b = create(:service_event, :service, order: nil, scheduled_on: route.route_date)
        create(:route_stop, route: route, service_event: event_a, position: 0)
        create(:route_stop, route: route, service_event: event_b, position: 1)

        allow(Routes::Optimization::Run).to receive(:call)
          .and_return(stub_result(success: true,
                                  warnings: [],
                                  event_ids: [ event_b.id, event_a.id ],
                                  duration: 3_600,
                                  distance: 5_000))

        post route_optimization_path(route)

        expect(route.reload.ordered_service_event_ids).to eq([ event_b.id, event_a.id ])
        expect(route.route_stops.find_by(service_event_id: event_b.id)&.position).to eq(0)
        expect(route.route_stops.find_by(service_event_id: event_a.id)&.position).to eq(1)
        expect(route.reload.estimated_drive_seconds).to eq(3_600)
        expect(route.estimated_drive_meters).to eq(5_000)
        expect(route.optimization_stale).to be(false)
      end
    end

    context 'when optimization fails' do
      it 'sets an alert and redirects back to the route' do
        allow(Routes::Optimization::Run).to receive(:call)
          .with(instance_of(Route))
          .and_return(stub_result(success: false, errors: [ 'Unable to optimize' ]))

        post route_optimization_path(route)

        expect(response).to redirect_to(route_path(route))
        expect(flash[:alert]).to include('Unable to optimize')
      end
    end
  end
end
