require "rails_helper"

RSpec.describe ServiceEventsHelper, type: :helper do
  describe "#service_event_status_badge" do
    let(:order) { create(:order) }

    around do |example|
      Routes::ServiceEventRouter.without_auto_assignment { example.run }
    end

    it "returns 'Overdue' badge for past events" do
      event = create(:service_event, order: order, scheduled_on: Date.yesterday)
      badge = helper.service_event_status_badge(event)

      expect(badge).to include("Overdue")
      expect(badge).to include("bg-rose-50")
    end

    it "returns 'Due soon' badge for events happening tomorrow" do
      event = create(:service_event, order: order, scheduled_on: Date.current + 1.day)
      badge = helper.service_event_status_badge(event)

      expect(badge).to include("Due soon")
      expect(badge).to include("bg-amber-50")
    end

    it "returns nil for events more than a day away" do
      event = create(:service_event, order: order, scheduled_on: Date.current + 5.days)
      expect(helper.service_event_status_badge(event)).to be_nil
    end
  end
end
