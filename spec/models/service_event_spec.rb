require "rails_helper"

RSpec.describe ServiceEvent, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  describe ".upcoming_week" do
    it "returns scheduled events through the next week, including overdue ones, ordered by date" do
      travel_to Date.new(2024, 5, 6) do
        overdue = create(:service_event, scheduled_on: Date.new(2024, 5, 4), status: :scheduled)
        upcoming = create(:service_event, scheduled_on: Date.new(2024, 5, 8), status: :scheduled)
        create(:service_event, scheduled_on: Date.new(2024, 5, 14), status: :scheduled) # beyond horizon
        create(:service_event, scheduled_on: Date.new(2024, 5, 7), status: :completed) # completed excluded

        expect(described_class.upcoming_week).to eq([ overdue, upcoming ])
      end
    end
  end

  describe "reports" do
    include ActiveSupport::Testing::TimeHelpers

    it "creates a report when a reportable event is completed" do
      type = create(:service_event_type_service)
      event = create(:service_event, :service, service_event_type: type, status: :scheduled)

      event.update!(status: :completed)

      expect(event.service_event_report).to be_present
      expect(event.service_event_report.data["customer_name"]).to eq(event.order.customer.display_name)
    end

    it "does not create a report for non-reportable events" do
      type = create(:service_event_type_delivery)
      event = create(:service_event, :delivery, service_event_type: type, status: :scheduled)

      event.update!(status: :completed)

      expect(event.service_event_report).to be_nil
    end
  end
end
