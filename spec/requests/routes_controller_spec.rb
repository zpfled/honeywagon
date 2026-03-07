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
      scope = Routes::Generation::Scope.new(
        company: user.company,
        scope_start: date,
        scope_end: date + 27.days,
        strategy: 'capacity_v1'
      )
      run = create(
        :route_generation_run,
        company: user.company,
        state: :active,
        scope_key: scope.scope_key,
        window_start: scope.window_start,
        window_end: scope.window_end
      )
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer, generation_run: run)

      assigned_order = create(:order, company: user.company, start_date: date, end_date: date + 1.day)
      assigned_event = create(:service_event, :service, order: assigned_order, route: route, scheduled_on: date, route_date: date)
      create(:route_stop, route: route, service_event: assigned_event, route_date: date, position: 0)

      unassigned_order = create(:order, company: user.company, start_date: date, end_date: date + 1.day)
      create(:service_event, :pickup, order: unassigned_order, scheduled_on: date)

      get calendar_routes_path(start: date.to_s, run_id: run.id)

      expect(response.body).to include('2 due · 1 assigned')
      expect(response.body).to include("Pickup · #{unassigned_order.customer.display_name}")
    end

    it "counts only due event assignments when generated stops include dump events" do
      date = Date.current.beginning_of_week(:sunday)
      scope = Routes::Generation::Scope.new(
        company: user.company,
        scope_start: date,
        scope_end: date + 27.days,
        strategy: 'capacity_v1'
      )
      run = create(
        :route_generation_run,
        company: user.company,
        state: :active,
        scope_key: scope.scope_key,
        window_start: scope.window_start,
        window_end: scope.window_end
      )
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer, generation_run: run)

      due_order = create(:order, company: user.company, start_date: date, end_date: date + 1.day)
      due_event = create(:service_event, :service, order: due_order, route: route, scheduled_on: date, route_date: date)
      dump_site = create(:dump_site, company: user.company)
      dump_event = create(:service_event, :dump, route: route, route_date: date, scheduled_on: date, dump_site: dump_site)

      create(:route_stop, route: route, service_event: due_event, route_date: date, position: 0)
      create(:route_stop, route: route, service_event: dump_event, route_date: date, position: 1)

      get calendar_routes_path(start: date.to_s, run_id: run.id)

      expect(response.body).to include('1 due · 1 assigned')
      expect(response.body).not_to include('Unassigned events')
    end
  end

  describe "GET /routes/day" do
    it "shows unassigned and assigned event buckets for a day" do
      date = Date.current
      scope = Routes::Generation::Scope.new(
        company: user.company,
        scope_start: date.beginning_of_week(:sunday),
        scope_end: date.beginning_of_week(:sunday) + 27.days,
        strategy: 'capacity_v1'
      )
      run = create(
        :route_generation_run,
        company: user.company,
        state: :active,
        scope_key: scope.scope_key,
        window_start: scope.window_start,
        window_end: scope.window_end
      )
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer, generation_run: run)

      assigned_order = create(:order, company: user.company, start_date: date, end_date: date)
      assigned_event = create(:service_event, :service, order: assigned_order, route: route, scheduled_on: date, route_date: date)
      create(:route_stop, route: route, service_event: assigned_event, route_date: date, position: 0)

      unassigned_order = create(:order, company: user.company, start_date: date, end_date: date)
      create(:service_event, :service, order: unassigned_order, scheduled_on: date)

      get day_routes_path(date: date.to_s, run_id: run.id)

      expect(response.body).to include('Unassigned due events')
      expect(response.body).to include('Assigned in active run')
      expect(response.body).to include(assigned_order.customer.display_name)
      expect(response.body).to include(unassigned_order.customer.display_name)
    end

    it "lists only due event assignments in the active run bucket" do
      date = Date.current
      scope = Routes::Generation::Scope.new(
        company: user.company,
        scope_start: date.beginning_of_week(:sunday),
        scope_end: date.beginning_of_week(:sunday) + 27.days,
        strategy: 'capacity_v1'
      )
      run = create(
        :route_generation_run,
        company: user.company,
        state: :active,
        scope_key: scope.scope_key,
        window_start: scope.window_start,
        window_end: scope.window_end
      )
      route = create(:route, company: user.company, route_date: date, truck: truck, trailer: trailer, generation_run: run)

      due_order = create(:order, company: user.company, start_date: date, end_date: date)
      due_event = create(:service_event, :pickup, order: due_order, route: route, scheduled_on: date, route_date: date)
      dump_site = create(:dump_site, company: user.company)
      dump_event = create(:service_event, :dump, route: route, scheduled_on: date, route_date: date, dump_site: dump_site)

      create(:route_stop, route: route, service_event: due_event, route_date: date, position: 0)
      create(:route_stop, route: route, service_event: dump_event, route_date: date, position: 1)

      get day_routes_path(date: date.to_s, run_id: run.id)

      expect(response.body).to include(due_order.customer.display_name)
      expect(response.body).not_to include(dump_site.name)
    end
  end
end
