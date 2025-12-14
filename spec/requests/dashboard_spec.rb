require "rails_helper"

RSpec.describe "Dashboard and landing", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "GET / (unauthenticated)" do
    it "renders the marketing landing page" do
      get unauthenticated_root_path
      expect(response.body).to include("Sign in")
      expect(response.body).to include("Create account")
    end
  end

  describe "GET / (authenticated)" do
    let(:user) { create(:user) }
    let!(:truck) { create(:truck, company: user.company) }
    let!(:trailer) { create(:trailer, company: user.company) }

    it "shows upcoming routes for the signed-in user" do
      travel_to Date.new(2024, 5, 6) do
        customer = create(:customer, business_name: "ACME Test Co")
        order = create(
          :order,
          company: user.company,
          created_by: user,
          customer: customer,
          start_date: Date.new(2024, 5, 5),
          end_date: Date.new(2024, 5, 10),
          status: "scheduled"
        )
        create(:service_event, :service, order: order, scheduled_on: Date.new(2024, 5, 7))
        route = create(:route, company: user.company, route_date: Date.new(2024, 5, 7))

        sign_in user
        get authenticated_root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.l(route.route_date, format: :long))
        expect(response.body).to include("Upcoming Routes")
        expect(response.body).to include("route")
      end
    end
  end
end
