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

    it "shows upcoming service events for the signed-in user" do
      travel_to Date.new(2024, 5, 6) do
        customer = create(:customer, company_name: "ACME Test Co")
        order = create(
          :order,
          user: user,
          customer: customer,
          start_date: Date.new(2024, 5, 5),
          end_date: Date.new(2024, 5, 10),
          status: "scheduled"
        )
        event = create(:service_event, :service, order: order, scheduled_on: Date.new(2024, 5, 7))

        sign_in user
        get authenticated_root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.l(event.scheduled_on, format: :long))
        expect(response.body).to include(customer.display_name)
        expect(response.body).to include("Mark completed")
      end
    end
  end
end
