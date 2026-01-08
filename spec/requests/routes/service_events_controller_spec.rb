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
        post postpone_route_service_event_path(route, service_event)

        new_route = company.routes.order(:route_date).last
        expect(new_route.route_date).to eq(route.route_date + 1.day)
        expect(response).to redirect_to(route_path(new_route))

        service_event.reload
        expect(service_event.route).to eq(new_route)
        expect(service_event.route_date).to eq(new_route.route_date)
      end
    end
  end

  describe 'POST /routes/:route_id/service_events/:id/advance' do
    let(:route) { create(:route, company: company, route_date: Date.current + 5.days) }
    let(:order) { create(:order, company: company, created_by: user) }
    let(:service_event) { create(:service_event, order: order, route: route, route_date: route.route_date) }

    context 'when an earlier eligible route exists' do
      let!(:previous_route) { create(:route, company: company, route_date: Date.current + 2.days) }

      it 'moves the service event to the previous route' do
        post advance_route_service_event_path(route, service_event)

        expect(response).to redirect_to(route_path(previous_route))
        service_event.reload
        expect(service_event.route).to eq(previous_route)
        expect(flash[:notice]).to eq('Service event moved to the previous route.')
      end
    end

    context 'when no earlier eligible route exists' do
      it 'shows an alert' do
        post advance_route_service_event_path(route, service_event)

        expect(response).to redirect_to(route_path(route))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST /routes/:route_id/service_events/:id/complete' do
    include ActiveSupport::Testing::TimeHelpers

    let(:route) { create(:route, company: company, route_date: Date.current) }
    let(:order) { create(:order, company: company, created_by: user, start_date: Date.current - 1, end_date: Date.current + 30) }
    let(:unit_type) { create(:unit_type, company: company) }
    let(:rate_plan) { create(:rate_plan, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:weekly]) }
    let!(:rental_line_item) { create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan) }
    let(:service_event) { create(:service_event, order: order, route: route, route_date: route.route_date, event_type: :service) }
    let!(:future_event) { create(:service_event, order: order, event_type: :service, scheduled_on: Date.current + 3.days) }

    it 'marks the service event as completed and reschedules future events' do
      travel_to Date.new(2024, 1, 1) do
        post complete_route_service_event_path(route, service_event)
      end

      expect(response).to redirect_to(route_path(route))
      expect(flash[:notice]).to eq('Service event marked completed.')
      expect(service_event.reload).to be_status_completed
      expect(future_event.reload.scheduled_on).to eq(Date.new(2024, 1, 8))
    ensure
      travel_back
    end

    context 'when completing a delivery event' do
      let(:delivery_order) { create(:order, company: company, created_by: user, start_date: Date.current - 1, end_date: Date.current + 10, status: 'scheduled') }
      let(:delivery_event) do
        create(:service_event, :delivery,
               order: delivery_order,
               route: route,
               route_date: route.route_date,
               scheduled_on: route.route_date)
      end

      it 'activates the order' do
        post complete_route_service_event_path(route, delivery_event)

        expect(delivery_order.reload.status).to eq('active')
      end
    end

    context 'when completing a pickup event' do
      let(:pickup_order) { create(:order, company: company, created_by: user, start_date: Date.current - 30, end_date: Date.current + 10, status: 'active') }
      let(:pickup_event) do
        create(:service_event, :pickup,
               order: pickup_order,
               route: route,
               route_date: route.route_date,
               scheduled_on: route.route_date)
      end

      it 'completes the order and updates the end date' do
        travel_to Date.new(2024, 1, 5) do
          post complete_route_service_event_path(route, pickup_event)
        end

        pickup_order.reload
        expect(pickup_order.status).to eq('completed')
        expect(pickup_order.end_date).to eq(Date.new(2024, 1, 5))
      end
    end
  end
end
