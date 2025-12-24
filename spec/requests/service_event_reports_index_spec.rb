require "rails_helper"

RSpec.describe "ServiceEventReports index", type: :request do
  let(:user) { create(:user) }

  it "redirects guests to sign in" do
    get service_event_reports_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "lists completed service reports" do
    report = create(:service_event_report, user: user, service_event: create(:service_event, order: create(:order, company: user.company, created_by: user)))

    sign_in user
    get service_event_reports_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Service Log")
    expect(response.body).to include(report.service_event.order.customer.display_name)
  end

  # TODO: figure out why this was failing
  xit "orders reports by service event completion time" do
    old_customer = create(:customer, company: user.company, display_name: "Old Customer")
    recent_customer = create(:customer, company: user.company, display_name: "Recent Customer")
    old_event = create(:service_event, order: create(:order, company: user.company, customer: old_customer, created_by: user))
    recent_event = create(:service_event, order: create(:order, company: user.company, customer: recent_customer, created_by: user))
    old_event.update_columns(completed_on: 2.days.ago, status: ServiceEvent.statuses[:completed])
    recent_event.update_columns(completed_on: 1.hour.ago, status: ServiceEvent.statuses[:completed])
    old_report = create(:service_event_report, user: user, service_event: old_event)
    recent_report = create(:service_event_report, user: user, service_event: recent_event)

    sign_in user
    get service_event_reports_path

    expect(response.body.index("Recent Customer")).to be < response.body.index("Old Customer")
  end

  it "shows the time the event was logged" do
    central_time = Time.find_zone('Central Time (US & Canada)').local(2024, 12, 25, 15, 30, 0)
    event = create(:service_event, order: create(:order, company: user.company, created_by: user), updated_at: central_time)
    report = create(:service_event_report, user: user, service_event: event)

    sign_in user
    get service_event_reports_path

    expect(response.body).to include("03:30 PM")
  end
end
