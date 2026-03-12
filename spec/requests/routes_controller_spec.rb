require 'rails_helper'

RSpec.describe "RoutesController", type: :request do
  let(:user) { create(:user) }
  let!(:truck) { create(:truck, company: user.company) }
  let!(:trailer) { create(:trailer, company: user.company) }

  before { sign_in user }

  describe "GET /routes/:id" do
    it "renders the show with detail presenter data" do
      route = create(:route, company: user.company, truck: truck, trailer: trailer)
      event = create(:service_event, :service, route: route, route_date: route.route_date)

      get route_path(route)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.l(route.route_date, format: "%A, %B %-d"))
      expect(response.body).to include(I18n.l(event.scheduled_on))
    end
  end

  describe "POST /routes" do
    it "creates a route on success" do
      params = { route: { route_date: Date.current, truck_id: truck.id, trailer_id: trailer.id } }

      expect {
        post routes_path, params: params
      }.to change { Route.count }.by(1)

      expect(response).to redirect_to(route_path(Route.last))
      follow_redirect!
      expect(response.body).to include('Route created.')
    end

    it "redirects back with an error on failure" do
      other_company = create(:company)
      other_truck = create(:truck, company: other_company)
      params = { route: { route_date: Date.current, truck_id: other_truck.id, trailer_id: nil } }

      post routes_path, params: params

      expect(response).to redirect_to(authenticated_root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /routes/reschedule_service_event" do
    it "rejects moving a delivery later than the order start date" do
      order = create(:order, company: user.company, created_by: user, start_date: Date.current, end_date: Date.current + 5.days)
      service_event = create(:service_event, :delivery, order: order, scheduled_on: Date.current - 1.day)

      post reschedule_service_event_routes_path, params: {
        service_event_id: service_event.id,
        target_date: (order.start_date + 1.day).to_s
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to include("status" => "error", "message" => "Deliveries cannot move later.")
    end
  end

  describe "PATCH /routes/:id" do
    it "updates a route on success" do
      route = create(:route, company: user.company, truck: truck, trailer: trailer)
      params = { route: { trailer_id: nil } }

      patch route_path(route), params: params

      expect(response).to redirect_to(route_path(route))
      follow_redirect!
      expect(response.body).to include('Route updated.')
      expect(route.reload.trailer_id).to be_nil
    end

    it "re-renders show with presenter data on failure" do
      route = create(:route, company: user.company, truck: truck, trailer: trailer)
      other_company = create(:company)
      invalid_truck = create(:truck, company: other_company)
      params = { route: { truck_id: invalid_truck.id } } # invalid: truck must belong to company

      patch route_path(route), params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Route for')
    end
  end

  describe "POST /routes/:id/push_to_calendar" do
    it "redirects with a notice on success" do
      route = create(:route, company: user.company, truck: truck, trailer: trailer)
      result = Routes::GoogleCalendarPusher::Result.new(success?: true, errors: [], warnings: [])

      allow(Routes::GoogleCalendarPusher).to receive(:new).with(route: route, user: user).and_return(double(call: result))

      post push_to_calendar_route_path(route)

      expect(response).to redirect_to(route_path(route))
      follow_redirect!
      expect(response.body).to include('Route pushed to Google Calendar.')
    end
  end

  describe "GET /routes/calendar" do
    it "keeps unassigned due events visible in counts" do
      date = Date.current.beginning_of_week(:sunday)
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer)

      assigned_order = create(:order, company: user.company, status: 'draft', start_date: date, end_date: date + 1.day)
      create(:service_event, :service, order: assigned_order, route: route, route_date: date, scheduled_on: date)

      unassigned_order = create(:order, company: user.company, status: 'draft', start_date: date, end_date: date + 1.day)
      unassigned_event = create(:service_event, :pickup, order: unassigned_order, scheduled_on: date)
      unassigned_event.route_stops.destroy_all

      get calendar_routes_path(start: date.to_s)

      expect(response.body).to include('2 due · 1 assigned')
      expect(response.body).to include("Pickup · #{unassigned_order.customer.display_name}")
    end

    it "counts only due event assignments when generated stops include dump events" do
      date = Date.current.beginning_of_week(:sunday)
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer)

      due_order = create(:order, company: user.company, status: 'draft', start_date: date, end_date: date + 1.day)
      create(:service_event, :service, order: due_order, route: route, route_date: date, scheduled_on: date)
      dump_site = create(:dump_site, company: user.company)
      create(:service_event, :dump, route: route, route_date: date, scheduled_on: date, dump_site: dump_site)

      get calendar_routes_path(start: date.to_s)

      expect(response.body).to include('1 due · 1 assigned')
      expect(response.body).not_to include('Unassigned events')
    end
  end

  describe "GET /routes/day" do
    it "shows unassigned and assigned event buckets for a day" do
      date = Date.current
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer)

      assigned_order = create(:order, company: user.company, status: 'draft', start_date: date, end_date: date)
      create(:service_event, :service, order: assigned_order, route: route, route_date: date, scheduled_on: date)

      unassigned_order = create(:order, company: user.company, status: 'draft', start_date: date, end_date: date)
      unassigned_event = create(:service_event, :service, order: unassigned_order, scheduled_on: date)
      unassigned_event.route_stops.destroy_all

      get day_routes_path(date: date.to_s)

      expect(response.body).to include('Unassigned due events')
      expect(response.body).to include('Routes for this day')
      expect(response.body).to include(assigned_order.customer.display_name)
      expect(response.body).to include(unassigned_order.customer.display_name)
    end

    it "lists only due event assignments in the assigned bucket" do
      date = Date.current
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer)

      due_order = create(:order, company: user.company, status: 'draft', start_date: date, end_date: date)
      create(:service_event, :pickup, order: due_order, route: route, route_date: date, scheduled_on: date)
      dump_site = create(:dump_site, company: user.company)
      create(:service_event, :dump, route: route, route_date: date, scheduled_on: date, dump_site: dump_site)

      get day_routes_path(date: date.to_s)

      expect(response.body).to include(due_order.customer.display_name)
      expect(response.body).not_to include(dump_site.name)
    end
  end

  describe "POST /routes/clear_day" do
    it "clears future day routes when no completed events are present" do
      date = Date.current + 2.days
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer)
      event = create(:service_event, :service, order: nil, route: route, scheduled_on: date)

      post clear_day_routes_path, params: { date: date.to_s }

      expect(response).to redirect_to(day_routes_path(date: date, strategy: 'capacity_v1'))
      expect(flash[:notice]).to include('Cleared 1 route')
      expect(Route.exists?(route.id)).to be(false)
      expect(RouteStop.exists?(service_event_id: event.id)).to be(false)
    end

    it "does not clear day routes when completed events are present" do
      date = Date.current + 2.days
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer)
      completed_event = create(:service_event, :service, :completed, order: nil, route: route, scheduled_on: date)

      post clear_day_routes_path, params: { date: date.to_s }

      expect(response).to redirect_to(day_routes_path(date: date, strategy: 'capacity_v1'))
      expect(flash[:alert]).to include('completed events')
      expect(Route.exists?(route.id)).to be(true)
      expect(RouteStop.exists?(route_id: route.id, service_event_id: completed_event.id)).to be(true)
    end
  end
end
