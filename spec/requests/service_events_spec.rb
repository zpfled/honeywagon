require "rails_helper"

RSpec.describe "ServiceEvents", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { create(:user) }

  describe "PATCH /service_events/:id" do
    it "updates the status, removes it from the dashboard scope, and creates a report when required" do
      travel_to Date.new(2024, 5, 6) do
        type = create(:service_event_type_service)
        event = create(:service_event, :service, order: create(:order, user: user), service_event_type: type, scheduled_on: Date.new(2024, 5, 7), status: :scheduled)

        sign_in user
        patch service_event_path(event), params: { service_event: { status: :completed } }

        expect(response).to redirect_to(authenticated_root_path)
        expect(event.reload).to be_status_completed
        expect(ServiceEvent.upcoming_week).not_to include(event)
        expect(event.service_event_report).to be_present
      end
    end
  end
end
