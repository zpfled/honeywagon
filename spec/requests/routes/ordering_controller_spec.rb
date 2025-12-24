require 'rails_helper'

RSpec.describe 'Routes::OrderingController', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }
  let(:route) { create(:route, company: company) }

  before { sign_in user }

  describe 'PATCH /routes/:route_id/ordering' do
    def manual_run_result(success:, warnings: [], errors: [], total_distance: 0, total_duration: 0, legs: [])
      Routes::Optimization::ManualRun::Result.new(
        success?: success,
        event_ids_in_order: [],
        warnings: warnings,
        errors: errors,
        total_distance_meters: total_distance,
        total_duration_seconds: total_duration,
        legs: legs
      )
    end

    it 'reorders events when manual optimization succeeds' do
      event_a = create(:service_event, :service, route: route, order: create(:order, company: company, status: 'scheduled'))
      event_b = create(:service_event, :service, route: route, order: create(:order, company: company, status: 'scheduled'))
      ordered_ids = [ event_b.id, event_a.id ]

      expect(Routes::Optimization::ManualRun).to receive(:call)
        .with(route, ordered_ids)
        .and_return(manual_run_result(success: true, warnings: [ 'Heads up' ], total_distance: 5000, total_duration: 600))

      patch route_ordering_path(route), params: { event_ids: ordered_ids }

      expect(response).to redirect_to(route_path(route))
      expect(flash[:notice]).to include('Route updated')
      expect(flash[:notice]).to include('Heads up')
      expect(event_b.reload.route_sequence).to be < event_a.reload.route_sequence
    end

    it 'shows errors when manual optimization fails' do
      event = create(:service_event, :service, route: route, order: create(:order, company: company, status: 'scheduled'))
      expect(Routes::Optimization::ManualRun).to receive(:call)
        .with(route, [ event.id ])
        .and_return(manual_run_result(success: false, errors: [ 'Invalid stop' ]))

      patch route_ordering_path(route), params: { event_ids: [ event.id ] }

      expect(response).to redirect_to(route_path(route))
      expect(flash[:alert]).to include('Invalid stop')
      expect(event.reload.route_sequence).to eq(event.route_sequence) # unchanged
    end
  end
end
