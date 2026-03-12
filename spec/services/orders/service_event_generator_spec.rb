require "rails_helper"

RSpec.describe Orders::ServiceEventGenerator do
  subject(:generate) { described_class.new(order, from_date: from_date).call }

  let(:none_schedule) { RatePlan::SERVICE_SCHEDULES[:none] }
  let(:weekly_schedule) { RatePlan::SERVICE_SCHEDULES[:weekly] }
  let(:biweekly_schedule) { RatePlan::SERVICE_SCHEDULES[:biweekly] }
  let(:monthly_schedule) { RatePlan::SERVICE_SCHEDULES[:monthly] }
  let(:from_date) { nil }

  around do |example|
    Routes::ServiceEventRouter.without_auto_assignment { example.run }
  end

  describe "weekend order with no recurring service" do
    let(:order) { create(:order, start_date: Date.new(2024, 7, 5), end_date: Date.new(2024, 7, 7)) }
    let!(:rate_plan) { create(:rate_plan, service_schedule: none_schedule) }

    before do
      create(:rental_line_item, order: order, rate_plan: rate_plan, service_schedule: none_schedule)
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
      create(:rental_line_item, order: order, rate_plan: rate_plan, service_schedule: biweekly_schedule)
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

  describe "monthly recurring rental" do
    let(:start_date) { Date.new(2024, 1, 1) }
    let(:end_date) { Date.new(2024, 4, 30) }
    let(:order) { create(:order, start_date: start_date, end_date: end_date) }
    let!(:rate_plan) { create(:rate_plan, service_schedule: monthly_schedule) }

    before do
      create(:rental_line_item, order: order, rate_plan: rate_plan, service_schedule: monthly_schedule)
    end

    it "creates monthly recurring service events" do
      generate

      service_dates = order.service_events.auto_generated.where(event_type: :service).order(:scheduled_on).pluck(:scheduled_on)
      expect(service_dates).to eq([ start_date + 30, start_date + 60, start_date + 90 ])
    end
  end

  describe "idempotency" do
    let(:order) { create(:order, start_date: Date.new(2024, 3, 1), end_date: Date.new(2024, 3, 29)) }
    let!(:rate_plan) { create(:rate_plan, :weekly) }

    before do
      create(:rental_line_item, order: order, rate_plan: rate_plan, service_schedule: weekly_schedule)
    end

    it "replaces existing auto-generated events on each run" do
      generate
      expect { generate }.not_to change { order.service_events.count }

      unique_dates = order.service_events.pluck(:scheduled_on)
      expect(unique_dates).to eq(unique_dates.uniq)
    end
  end

  describe "future-only generation" do
    let(:from_date) { Date.new(2024, 1, 15) }
    let(:order) { create(:order, start_date: Date.new(2024, 1, 1), end_date: Date.new(2024, 2, 1)) }
    let!(:rate_plan) { create(:rate_plan, :weekly) }

    before do
      create(:rental_line_item, order: order, rate_plan: rate_plan, service_schedule: weekly_schedule)
      service_type = ServiceEventType.find_or_create_by!(key: "service") do |t|
        t.name = "Service"
        t.requires_report = true
        t.report_fields = []
      end

      order.service_events.create!(
        event_type: :service,
        scheduled_on: Date.new(2024, 1, 5),
        status: :scheduled,
        auto_generated: true,
        service_event_type: service_type,
        user: order.created_by
      )
    end

    it "only generates events on or after the provided date" do
      existing_ids = order.service_events.auto_generated.pluck(:id)

      generate

      new_dates = order.service_events.auto_generated.where.not(id: existing_ids).pluck(:scheduled_on)
      expect(new_dates).to all(be >= from_date)
      expect(new_dates).to include(order.end_date)
    end

    it "does not delete auto-generated events before the provided date" do
      past_event_ids = order.service_events.auto_generated.where("scheduled_on < ?", from_date).pluck(:id)

      generate

      remaining_ids = order.service_events.auto_generated.where(id: past_event_ids).pluck(:id)
      expect(remaining_ids).to match_array(past_event_ids)
    end
  end

  describe "delivery splitting" do
    let(:start_date) { Date.new(2024, 8, 1) }
    let(:end_date) { Date.new(2024, 8, 10) }
    let(:order) { create(:order, start_date: start_date, end_date: end_date) }
    let!(:unit_type) { create(:unit_type, :standard, company: order.company) }
    let!(:rate_plan) { create(:rate_plan, service_schedule: none_schedule, unit_type: unit_type, company: order.company) }

    before do
      create(:trailer, company: order.company, capacity_spots: 2, preference_rank: 1)
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, service_schedule: none_schedule, quantity: 5)
    end

    it "splits delivery events based on trailer capacity" do
      generate

      deliveries = order.service_events.auto_generated.where(event_type: :delivery).order(:delivery_batch_sequence)
      expect(deliveries.count).to eq(3)
      expect(deliveries.pluck(:delivery_batch_total).uniq).to eq([ 3 ])
      expect(deliveries.pluck(:delivery_batch_sequence)).to eq([ 1, 2, 3 ])

      quantities = deliveries.map do |event|
        event.service_event_units.sum(:quantity)
      end
      expect(quantities).to eq([ 2, 2, 1 ])
    end
  end

  describe "pickup splitting" do
    let(:start_date) { Date.new(2024, 8, 1) }
    let(:end_date) { Date.new(2024, 8, 10) }
    let(:order) { create(:order, start_date: start_date, end_date: end_date) }
    let!(:unit_type) { create(:unit_type, :standard, company: order.company) }
    let!(:rate_plan) { create(:rate_plan, service_schedule: none_schedule, unit_type: unit_type, company: order.company) }

    before do
      create(:trailer, company: order.company, capacity_spots: 2, preference_rank: 1)
      create(:trailer, company: order.company, capacity_spots: 10, preference_rank: 2)
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, service_schedule: none_schedule, billing_period: RatePlan::BILLING_PERIODS.first, quantity: 12)
    end

    it "splits pickup events based on trailer capacities" do
      generate

      pickups = order.service_events.auto_generated.where(event_type: :pickup).order(:pickup_batch_sequence)
      expect(pickups.count).to eq(2)
      expect(pickups.pluck(:pickup_batch_total).uniq).to eq([ 2 ])
      expect(pickups.pluck(:pickup_batch_sequence)).to eq([ 1, 2 ])

      quantities = pickups.map { |event| event.service_event_units.sum(:quantity) }
      expect(quantities.sort).to eq([ 2, 10 ])
    end
  end
  describe "service-only orders" do
    let(:order) { create(:order, start_date: Date.new(2024, 6, 1), end_date: Date.new(2024, 7, 1)) }

    before do
      create(:service_line_item, order: order, service_schedule: weekly_schedule, units_serviced: 5)
    end

    it "derives cadence from service-only line items" do
      generate

      service_events = order.service_events.auto_generated.where(event_type: :service).order(:scheduled_on).pluck(:scheduled_on)
      expect(service_events).to include(Date.new(2024, 6, 8))
      expect(service_events).to all(be >= order.start_date)
    end
  end
end
