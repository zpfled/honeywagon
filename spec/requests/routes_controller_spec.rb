require 'rails_helper'

RSpec.describe "RoutesController", type: :request do
  let(:user) { create(:user) }
  let!(:truck) { create(:truck, company: user.company) }
  let!(:trailer) { create(:trailer, company: user.company) }

  before { sign_in user }

  describe "GET /routes" do
    it "renders the index with presenter rows" do
      route = create(:route, company: user.company, truck: truck, trailer: trailer)
      create(:service_event, :delivery, route: route, route_date: route.route_date)

      get routes_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.l(route.route_date))
    end
  end

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

    it "re-renders index with presenter rows on failure" do
      other_company = create(:company)
      other_truck = create(:truck, company: other_company)
      params = { route: { route_date: Date.current, truck_id: other_truck.id, trailer_id: nil } }

      post routes_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Routes')
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
end
