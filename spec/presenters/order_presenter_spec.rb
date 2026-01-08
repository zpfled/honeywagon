require "rails_helper"

RSpec.describe OrderPresenter do
  let(:view_context) do
    Class.new do
      include ActionView::Helpers::DateHelper
      include ActionView::Helpers::TextHelper
      include ActionView::Helpers::NumberHelper
      include ActionView::Helpers::TranslationHelper
      include ActionView::Helpers::TagHelper
    end.new
  end

  let(:company) { create(:company) }
  let(:customer) { create(:customer, company: company, business_name: 'Acme') }
  let(:location) { create(:location, customer: customer, street: '123 Main', city: 'Madison', state: 'WI') }
  let(:order) { create(:order, company: company, customer: customer, location: location, start_date: Date.new(2024, 1, 1), end_date: Date.new(2024, 1, 8)) }
  let(:unit_type) { create(:unit_type, :standard, company: company) }
  let(:rate_plan) { create(:rate_plan, unit_type: unit_type, company: company, price_cents: 1_000) }
  let(:presenter) { described_class.new(order, view_context: view_context) }

  describe "#location_address_line" do
    it "formats street and city/state" do
      expect(presenter.location_address_line).to eq("123 Main Madison, WI")
    end

    it "returns nil when street is missing" do
      order.location.update!(street: nil)
      expect(presenter.location_address_line).to be_nil
    end
  end

  describe "date helpers" do
    it "formats start and end dates" do
      expect(presenter.start_date).to eq(view_context.l(order.start_date, format: :long))
      expect(presenter.end_date).to eq(view_context.l(order.end_date, format: :long))
    end

    it "computes date_range_days and date_range_humanized" do
      expect(presenter.date_range_days).to eq(8)
      expect(presenter.date_range_humanized).to eq("1 week")
    end

    it "handles missing dates safely" do
      order.update_column(:start_date, nil)
      order.update_column(:end_date, nil)
      expect(presenter.date_range_days).to be_nil
      expect(presenter.date_range_humanized).to be_nil
    end
  end

  describe "line item helpers" do
    it "builds labels for rental and service items" do
      rental_item = create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 2)
      service_item = create(:service_line_item, order: order, description: 'Extra service', units_serviced: 3, rate_plan: rate_plan)

      expect(presenter.line_item_label(rental_item)).to eq(unit_type.name)
      expect(presenter.line_item_label(service_item)).to eq('Extra service')
      expect(presenter.line_item_quantity_value(rental_item)).to eq(2)
      expect(presenter.line_item_quantity_value(service_item)).to eq(3)
    end

    it "formats line item schedule labels" do
      rental_item = create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 1)
      expect(presenter.line_item_schedule(rental_item)).to include(rate_plan.service_schedule.to_s.humanize)
    end
  end

  describe "status helpers" do
    it "returns a status badge with humanized text" do
      expect(presenter.status_badge).to include(order.status.humanize)
    end

    it "normalizes blank statuses to unknown" do
      order.update_column(:status, nil)
      expect(presenter.status).to eq("unknown")
    end
  end

  describe "totals and counts" do
    it "computes line items subtotal from line items" do
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 2, unit_price_cents: 1_000, subtotal_cents: 2_000)
      expect(presenter.line_items_subtotal_cents).to eq(2_000)
      expect(presenter.line_items_subtotal_currency).to eq("$20.00")
    end

    it "counts line items and units" do
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 1)
      create(:service_line_item, order: order, description: 'Service', units_serviced: 1, rate_plan: rate_plan)
      unit = create(:unit, company: company, unit_type: unit_type)
      create(:order_unit, order: order, unit: unit)

      expect(presenter.line_items_count).to eq(2)
      expect(presenter.units_count).to eq(1)
    end
  end

  describe "service events" do
    it "loads and orders service events" do
      later = create(:service_event, :service, order: order, scheduled_on: Date.current + 2.days)
      earlier = create(:service_event, :service, order: order, scheduled_on: Date.current)

      expect(presenter.service_events.first).to eq(earlier)
      expect(presenter.service_events).to include(later)
      expect(presenter.service_events_count).to eq(2)
    end

    it "builds a warning badge when the next service is due soon" do
      rate_plan.update!(service_schedule: RatePlan::SERVICE_SCHEDULES[:weekly])
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 1)

      completed = create(:service_event, :service, order: order, status: :completed)
      completed.update_column(:completed_on, Date.current - 4.days)

      badge = presenter.service_status_badge
      expect(badge).to include('Last serviced')
      expect(badge).to include('bg-amber-100')
    end

    it "builds an overdue badge when service is late" do
      rate_plan.update!(service_schedule: RatePlan::SERVICE_SCHEDULES[:weekly])
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 1)

      completed = create(:service_event, :service, order: order, status: :completed)
      completed.update_column(:completed_on, Date.current - 10.days)

      badge = presenter.service_status_badge
      expect(badge).to include('bg-rose-100')
    end

    it "builds a not scheduled badge when no upcoming service exists" do
      badge = presenter.next_service_badge
      expect(badge).to include('Not scheduled')
      expect(badge).to include('bg-rose-100')
    end

    it "uses pickup events for next scheduled" do
      pickup = create(:service_event, :pickup, order: order, status: :scheduled, scheduled_on: Date.current + 2.days)
      badge = presenter.next_service_badge
      expect(badge).to include("Pickup scheduled #{pickup.scheduled_on.strftime('%b %-d, %Y')}")
    end
  end

  describe "money helpers" do
    it "formats line item price from cents" do
      line_item = double("LineItem", unit_price_cents: 1500, unit_price: nil)
      allow(line_item).to receive(:respond_to?).with(:unit_price_cents).and_return(true)
      allow(line_item).to receive(:respond_to?).with(:unit_price).and_return(true)

      expect(presenter.line_item_unit_price(line_item)).to eq("$15.00")
    end

    it "formats line item subtotal from decimal" do
      line_item = double("LineItem", subtotal_cents: nil, subtotal: 25)
      allow(line_item).to receive(:respond_to?).with(:subtotal_cents).and_return(true)
      allow(line_item).to receive(:respond_to?).with(:subtotal).and_return(true)

      expect(presenter.line_item_subtotal(line_item)).to eq("$25.00")
    end
  end

  describe "#units_count" do
    it "prefers the provided units count when present" do
      presenter = described_class.new(order, view_context: view_context, units_count: 7)
      expect(presenter.units_count).to eq(7)
    end
  end
end
