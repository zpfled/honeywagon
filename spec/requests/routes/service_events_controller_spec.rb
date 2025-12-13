require 'rails_helper'

RSpec.describe 'Routes::ServiceEventsController', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }

  before { sign_in user }

  describe 'POST /routes/:route_id/service_events/:id/postpone' do
    let(:route) { create(:route, company: company, route_date: Date.current) }
    let(:order) { create(:order, company: company, created_by: user) }
    let(:service_event) { create(:service_event, order: order, route: route, route_date: route.route_date) }

    context 'when a future route exists' do
      let!(:next_route) { create(:route, company: company, route_date: route.route_date + 2.days) }

      it 'moves the service event to the next available route' do
        post postpone_route_service_event_path(route, service_event)

        expect(response).to redirect_to(route_path(next_route))
        service_event.reload
        expect(service_event.route).to eq(next_route)
        expect(service_event.route_date).to eq(next_route.route_date)
        expect(flash[:notice]).to eq('Service event postponed to the next route.')
      end
    end

    context 'when no future route exists' do
      it 'creates a route for the following day and assigns the service event' do
        expect {
          post postpone_route_service_event_path(route, service_event)
        }.to change { company.routes.count }.by(1)

        new_route = company.routes.order(:route_date).last
        expect(new_route.route_date).to eq(route.route_date + 1.day)
        expect(response).to redirect_to(route_path(new_route))

        service_event.reload
        expect(service_event.route).to eq(new_route)
        expect(service_event.route_date).to eq(new_route.route_date)
      end
    end
  end
end
