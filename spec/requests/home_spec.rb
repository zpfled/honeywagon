require "rails_helper"

RSpec.describe "Home dashboard", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  describe "GET /" do
    it "renders upcoming service events" do
      travel_to Date.new(2024, 5, 6) do
        customer = create(:customer, company_name: "ACME Test Co")
        order = create(
          :order,
          customer: customer,
          start_date: Date.new(2024, 5, 5),
          end_date: Date.new(2024, 5, 10),
          status: "scheduled"
        )
        event = create(:service_event, order: order, scheduled_on: Date.new(2024, 5, 7), event_type: :service)

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.l(event.scheduled_on, format: :long))
        expect(response.body).to include(customer.company_name)
        expect(response.body).to include("Mark completed")
      end
    end
  end
end
