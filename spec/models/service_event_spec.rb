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

  describe 'completed_on tracking' do
    it 'stamps completed_on when event is completed' do
      event = create(:service_event, status: :scheduled)
      freeze_time do
        event.update!(status: :completed)
        expect(event.completed_on).to eq(Date.current)
      end
    end
  end

  describe '#estimated_gallons_pumped' do
    it 'returns zero for delivery events' do
      event = create(:service_event, :delivery)
      expect(event.estimated_gallons_pumped).to eq(0)
    end

    it 'returns 10 gallons per ADA/standard unit for service/pickup events' do
      order = create(:order, status: 'scheduled')
      unit_type = create(:unit_type, :standard, company: order.company)
      rate_plan = create(:rate_plan, unit_type: unit_type)
      create(:order_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 3)

      event = create(:service_event, :service, order: order)

      expect(event.estimated_gallons_pumped).to eq(30)
    end
  end
  describe "route auto-assignment" do
    it "assigns a newly created event to a nearby route" do
      company = create(:company)
      create(:truck, company: company)
      create(:trailer, company: company)
      route = create(:route, company: company, route_date: Date.today + 1.day)
      order = create(:order, company: company)

      event = create(:service_event, :service, order: order, scheduled_on: route.route_date, route: nil)

      expect(event.reload.route).to eq(route)
    end
  end
end
