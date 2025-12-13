require "rails_helper"

RSpec.describe "ServiceEventReports index", type: :request do
  let(:user) { create(:user) }

  it "redirects guests to sign in" do
    get service_event_reports_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "lists completed service reports" do
    report = create(:service_event_report, user: user, service_event: create(:service_event, order: create(:order, user: user)))

    sign_in user
    get service_event_reports_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Service Log")
    expect(response.body).to include(report.service_event.order.customer.display_name)
  end
end
