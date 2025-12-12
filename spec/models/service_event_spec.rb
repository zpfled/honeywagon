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
end
