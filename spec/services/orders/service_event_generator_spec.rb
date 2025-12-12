require "rails_helper"

RSpec.describe Orders::ServiceEventGenerator do
  subject(:generate) { described_class.new(order).call }

  let(:none_schedule) { RatePlan::SERVICE_SCHEDULES[:none] }
  let(:weekly_schedule) { RatePlan::SERVICE_SCHEDULES[:weekly] }
  let(:biweekly_schedule) { RatePlan::SERVICE_SCHEDULES[:biweekly] }

  describe "weekend order with no recurring service" do
    let(:order) { create(:order, start_date: Date.new(2024, 7, 5), end_date: Date.new(2024, 7, 7)) }
    let!(:rate_plan) { create(:rate_plan, service_schedule: none_schedule) }

    before do
      create(:order_line_item, order: order, rate_plan: rate_plan, service_schedule: none_schedule)
    end

    it "creates only delivery and pickup events" do
      generate

      expect(order.service_events.auto_generated.count).to eq(2)
      expect(order.service_events.order(:scheduled_on).pluck(:event_type, :scheduled_on)).to eq(
        [
          [ "delivery", order.start_date ],
          [ "pickup", order.end_date ]
        ]
      )
    end
  end

  describe "long biweekly rental" do
    let(:start_date) { Date.new(2024, 1, 1) }
    let(:end_date) { start_date + 5.months }
    let(:order) { create(:order, start_date: start_date, end_date: end_date) }
    let!(:rate_plan) { create(:rate_plan, :biweekly) }

    before do
      create(:order_line_item, order: order, rate_plan: rate_plan, service_schedule: biweekly_schedule)
    end

    it "creates delivery, pickup, and recurring service events" do
      generate

      events = order.service_events.auto_generated.order(:scheduled_on)
      service_events = events.select(&:event_type_service?)

      expect(events.first).to have_attributes(event_type: "delivery", scheduled_on: start_date)
      expect(events.last).to have_attributes(event_type: "pickup", scheduled_on: end_date)

      expected_service_dates = []
      current = start_date + 14
      while current < end_date
        expected_service_dates << current
        current += 14
      end

      expect(service_events.map(&:scheduled_on)).to eq(expected_service_dates)
    end
  end

  describe "idempotency" do
    let(:order) { create(:order, start_date: Date.new(2024, 3, 1), end_date: Date.new(2024, 3, 29)) }
    let!(:rate_plan) { create(:rate_plan, :weekly) }

    before do
      create(:order_line_item, order: order, rate_plan: rate_plan, service_schedule: weekly_schedule)
    end

    it "replaces existing auto-generated events on each run" do
      generate
      expect { generate }.not_to change { order.service_events.count }

      unique_dates = order.service_events.pluck(:scheduled_on)
      expect(unique_dates).to eq(unique_dates.uniq)
    end
  end
end
