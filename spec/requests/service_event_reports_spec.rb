require "rails_helper"

RSpec.describe "ServiceEventReports", type: :request do
  let(:user) { create(:user) }

  describe "GET /service_event_reports/new" do
    it "renders the report form for reportable events" do
      event = create(:service_event, :service, order: create(:order, user: user))

      sign_in user
      get new_service_event_report_path(service_event_id: event.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Estimated gallons pumped")
    end
    it "redirects for non-reportable events" do
      event = create(:service_event, :delivery, order: create(:order, user: user))

      sign_in user
      get new_service_event_report_path(service_event_id: event.id)

      expect(response).to redirect_to(authenticated_root_path)
      expect(flash[:alert]).to match(/does not require a report/i)
    end
  end

  describe "POST /service_event_reports" do
    it "creates a report and completes the event" do
      event = create(:service_event, :service, status: :scheduled, order: create(:order, user: user))

      sign_in user
      post service_event_reports_path, params: {
        service_event_id: event.id,
        service_event_report: {
          estimated_gallons_pumped: 150,
          units_pumped: 3
        }
      }

      expect(response).to redirect_to(authenticated_root_path)
      expect(event.reload).to be_status_completed
      report = event.service_event_report
      expect(report.data["estimated_gallons_pumped"]).to eq("150")
      expect(report.data["units_pumped"]).to eq("3")
      expect(report.data["customer_name"]).to eq(event.order.customer.display_name)
      expect(report.data["customer_address"]).to include(event.order.location.city)
    end
  end
end
