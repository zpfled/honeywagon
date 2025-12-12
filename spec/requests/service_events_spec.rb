require "rails_helper"

RSpec.describe "ServiceEvents", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  describe "PATCH /service_events/:id" do
    it "updates the status and removes it from the dashboard scope" do
      travel_to Date.new(2024, 5, 6) do
        event = create(:service_event, scheduled_on: Date.new(2024, 5, 7), status: :scheduled)

        patch service_event_path(event), params: { service_event: { status: :completed } }

        expect(response).to redirect_to(root_path)
        expect(event.reload).to be_status_completed
        expect(ServiceEvent.upcoming_week).not_to include(event)
      end
    end
  end
end
