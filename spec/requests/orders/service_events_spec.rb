require 'rails_helper'
require 'cgi'

RSpec.describe "Order service events management", type: :request do
  let(:user) { create(:user) }
  let(:order) { create(:order, company: user.company, created_by: user) }
  let!(:service_event) { create(:service_event, order: order, user: user) }

  before { sign_in user }

  it "soft deletes the service event" do
    delete order_service_event_path(order, service_event)

    expect(response).to redirect_to(order_path(order))

    deleted_record = ServiceEvent.with_deleted.find(service_event.id)
    expect(deleted_record.deleted_at).to be_present
    expect(deleted_record.deleted_by).to eq(user)
  end

  it "handles missing events gracefully" do
    delete order_service_event_path(order, 'bad id')

    expect(response).to redirect_to(order_path(order))
    follow_redirect!
    expect(response.body).to include('could not be found')
  end

  describe "assigning service events to routes" do
    around do |example|
      Routes::ServiceEventRouter.without_auto_assignment do
        Route.without_auto_assignment { example.run }
      end
    end

    let(:scheduled_on) { Date.current }
    let!(:service_event) { create(:service_event, order: order, user: user, route: nil, scheduled_on: scheduled_on) }
    let!(:route_in_window) do
      create(:route, company: user.company, route_date: scheduled_on + 3.days, truck: create(:truck, company: user.company))
    end
    let!(:route_outside_window) do
      create(:route, company: user.company, route_date: scheduled_on + 20.days, truck: create(:truck, company: user.company))
    end

    it "assigns to a route within 2 weeks and aligns dates to the route" do
      patch assign_route_order_service_event_path(order, service_event), params: { route_id: route_in_window.id }

      expect(response).to redirect_to(order_path(order))
      service_event.reload
      expect(service_event.route).to eq(route_in_window)
      expect(service_event.route_date).to eq(route_in_window.route_date)
      expect(service_event.scheduled_on).to eq(route_in_window.route_date)
    end

    it "rejects routes outside the 2-week window" do
      patch assign_route_order_service_event_path(order, service_event), params: { route_id: route_outside_window.id }

      expect(response).to redirect_to(order_path(order))
      follow_redirect!
      expect(response.body).to include('within 2 weeks')
      service_event.reload
      expect(service_event.route).to be_nil
    end
  end

  describe "creating service events" do
    it "creates a manual service event even in the past" do
      expect do
        post order_service_events_path(order), params: {
          service_event: {
            event_type: 'service',
            scheduled_on: Date.yesterday
          }
        }
      end.to change { order.service_events.count }.by(1)

      expect(response).to redirect_to(order_path(order))
      manual_event = order.service_events.order(:created_at).last
      expect(manual_event.event_type).to eq('service')
      expect(manual_event.scheduled_on).to eq(Date.yesterday)
      expect(manual_event.auto_generated?).to be(false)
    end

    it "surfaces validation errors" do
      expect do
        post order_service_events_path(order), params: { service_event: { event_type: 'service' } }
      end.not_to change { order.service_events.count }

      expect(response).to redirect_to(order_path(order))
      follow_redirect!
      expect(CGI.unescapeHTML(response.body)).to include("Scheduled on can't be blank")
    end
  end
end
