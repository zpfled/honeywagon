require 'rails_helper'

RSpec.describe 'Routes::OptimizationsController', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }
  let(:route) { create(:route, company: company) }

  before { sign_in user }

  describe 'POST /routes/:route_id/optimization' do
    def stub_result(success:, warnings: [], errors: [])
      Routes::Optimization::Run::Result.new(
        success?: success,
        event_ids_in_order: [],
        warnings: warnings,
        errors: errors,
        simulation: nil
      )
    end

    context 'when optimization succeeds' do
      it 'sets a notice and redirects back to the route' do
        allow(Routes::Optimization::Run).to receive(:call)
          .with(instance_of(Route))
          .and_return(stub_result(success: true, warnings: [ 'Simulated warning' ]))

        post route_optimization_path(route)

        expect(response).to redirect_to(route_path(route))
        expect(flash[:notice]).to include('Optimization result')
        expect(flash[:notice]).to include('Simulated warning')
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
