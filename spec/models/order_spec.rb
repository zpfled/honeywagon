require "rails_helper"

RSpec.describe Order, type: :model do
  describe "associations" do
    it "belongs to a customer" do
      order = create(:order)
      expect(order.customer).to be_a(Customer)
    end

    it "belongs to a location" do
      order = create(:order)
      expect(order.location).to be_a(Location)
    end

    it "has many order_units" do
      order = create(:order)
      unit  = create(:unit)
      order_unit = create(:order_unit, order: order, unit: unit, placed_on: order.start_date)

      expect(order.order_units).to include(order_unit)
      expect(order.units).to include(unit)
    end
  end

  describe "validations" do
    it "is valid with default factory" do
      expect(build(:order)).to be_valid
    end

    it "is invalid without a customer" do
      order = build(:order, customer: nil)
      expect(order).not_to be_valid
      expect(order.errors[:customer]).to be_present
    end

    it "is invalid without a location" do
      order = build(:order, location: nil)
      expect(order).not_to be_valid
      expect(order.errors[:location]).to be_present
    end

    it "is invalid without a start_date" do
      order = build(:order, start_date: nil)
      expect(order).not_to be_valid
      expect(order.errors[:start_date]).to be_present
    end

    it "is invalid without an end_date" do
      order = build(:order, end_date: nil)
      expect(order).not_to be_valid
      expect(order.errors[:end_date]).to be_present
    end

    it "is invalid when end_date is before start_date" do
      order = build(:order, start_date: Date.today, end_date: 2.days.ago)
      expect(order).not_to be_valid
      expect(order.errors[:end_date]).to include("must be on or after start date")
    end

    it "only allows known statuses" do
      valid_order   = build(:order, status: Order::STATUSES.first)
      invalid_order = build(:order, status: "banana")

      expect(valid_order).to be_valid
      expect(invalid_order).not_to be_valid
      expect(invalid_order.errors[:status]).to be_present
    end
  end

  describe "callbacks" do
    it "recalculates totals before save" do
      order = build(
        :order,
        rental_subtotal_cents: 10_000,
        delivery_fee_cents:    2_500,
        pickup_fee_cents:      2_500,
        discount_cents:        1_000,
        tax_cents:             1_000,
        total_cents:           0
      )

      order.save!

      expect(order.reload.total_cents).to eq(15_000)
    end
  end

  describe "status helpers" do
    Order::STATUSES.each do |status|
      it "##{status}? returns true when status is '#{status}'" do
        order = build(:order, status: status)
        expect(order.public_send("#{status}?")).to be(true)
      end

      it "##{status}? returns false when status is not '#{status}'" do
        other_status = (Order::STATUSES - [ status ]).first
        order = build(:order, status: other_status)
        expect(order.public_send("#{status}?")).to be(false)
      end
    end
  end

  describe "scopes" do
    describe ".upcoming" do
      it "returns orders that start today or later" do
        past_order   = create(:order, start_date: Date.today - 5.days, end_date: Date.today - 1.day)
        today_order  = create(:order, start_date: Date.today,        end_date: Date.today + 2.days)
        future_order = create(:order, start_date: Date.today + 5.days, end_date: Date.today + 7.days)

        result = described_class.upcoming

        expect(result).to include(today_order, future_order)
        expect(result).not_to include(past_order)
      end
    end

    describe ".active_on" do
      it "returns orders active on a given date" do
        date = Date.today

        active_order      = create(:order, start_date: date - 1.day, end_date: date + 1.day)
        before_order      = create(:order, start_date: date - 10.days, end_date: date - 5.days)
        after_order       = create(:order, start_date: date + 1.day, end_date: date + 10.days)
        edge_start_order  = create(:order, start_date: date,          end_date: date + 3.days)
        edge_end_order    = create(:order, start_date: date - 3.days, end_date: date)

        result = described_class.active_on(date)

        expect(result).to include(active_order, edge_start_order, edge_end_order)
        expect(result).not_to include(before_order, after_order)
      end
    end
  end

  describe "unit lifecycle" do
    let(:unit)  { create(:unit, status: "available") }
    let(:order) { create(:order, status: "draft") }

    before do
      create(:order_unit, order: order, unit: unit, placed_on: order.start_date)
    end

    it "marks units as rented when order becomes scheduled" do
      expect(unit.status).to eq("available")

      order.update!(status: "scheduled")

      expect(unit.reload.status).to eq("rented")
    end

    it "marks units as rented when order becomes active" do
      order.update!(status: "active")
      expect(unit.reload.status).to eq("rented")
    end

    it "releases units back to available when order is completed and unit not on other active orders" do
      order.update!(status: "scheduled")
      expect(unit.reload.status).to eq("rented")

      order.update!(status: "completed")

      expect(unit.reload.status).to eq("available")
    end
  end

  describe "service event generation" do
    it "generates events when transitioning to scheduled" do
      order = create(
        :order,
        status: "draft",
        start_date: Date.new(2024, 9, 2),
        end_date: Date.new(2024, 9, 6)
      )
      create(:order_line_item, order: order, service_schedule: RatePlan::SERVICE_SCHEDULES[:none])

      expect { order.schedule! }.to change { order.service_events.count }.from(0).to(2)
      expect(order.service_events.order(:scheduled_on).pluck(:event_type)).to eq(%w[delivery pickup])
    end
  end

  describe "#recalculate_totals!" do
    it "sets total_cents from the component fields" do
      order = create(
        :order,
        rental_subtotal_cents: 10_000,
        delivery_fee_cents:    2_500,
        pickup_fee_cents:      2_500,
        discount_cents:        1_000,
        tax_cents:             1_000,
        total_cents:           0
      )

      order.recalculate_totals!

      expect(order.total_cents).to eq(15_000) # 10000 + 2500 + 2500 - 1000 + 1000
    end
  end
end
