require "rails_helper"

RSpec.describe "ServiceEventReports index", type: :request do
  it "lists completed service reports" do
    report = create(:service_event_report)

    get service_event_reports_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Service Log")
    expect(response.body).to include(report.service_event.order.customer.display_name)
  end
end
