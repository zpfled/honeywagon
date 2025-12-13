require "rails_helper"

RSpec.describe OrderUnit, type: :model do
  describe "associations" do
    it "belongs to an order and a unit" do
      order_unit = create(:order_unit)

      expect(order_unit.order).to be_a(Order)
      expect(order_unit.unit).to  be_a(Unit)
    end
  end

  describe "validations" do
    it "is invalid without placed_on" do
      order_unit = build(:order_unit, placed_on: nil)

      expect(order_unit).not_to be_valid
      expect(order_unit.errors[:placed_on]).to be_present
    end

    it "is invalid if removed_on is before placed_on" do
      order_unit = build(
        :order_unit,
        placed_on: Date.today,
        removed_on: 2.days.ago
      )

      expect(order_unit).not_to be_valid
      expect(order_unit.errors[:removed_on]).to include("must be on or after placed_on")
    end

    it "is invalid without a billing_period" do
      order_unit = build(:order_unit, billing_period: nil)

      expect(order_unit).not_to be_valid
      expect(order_unit.errors[:billing_period]).to include("can't be blank")
    end

    it "is invalid with an unsupported billing_period" do
      order_unit = build(:order_unit, billing_period: 'weekly')

      expect(order_unit).not_to be_valid
      expect(order_unit.errors[:billing_period]).to include("is not included in the list")
    end

    describe "unit availability validation" do
      let(:start_date) { Date.today }
      let(:end_date)   { Date.today + 3.days }

      it "allows attaching a unit when there is no overlapping blocking order" do
        unit  = create(:unit, status: "available")
        order = create(:order, start_date: start_date, end_date: end_date, status: "scheduled")

        order_unit = build(:order_unit, order: order, unit: unit, placed_on: start_date)

        expect(order_unit).to be_valid
      end

      it "disallows attaching a unit when there is an overlapping blocking order" do
        unit = create(:unit, status: "available")

        # First blocking order overlaps the window
        existing_order = create(
          :order,
          start_date: start_date,
          end_date:   end_date,
          status:     "active"
        )
        create(:order_unit, order: existing_order, unit: unit, placed_on: existing_order.start_date)

        # Second order tries to use the same unit in an overlapping range
        new_order = create(
          :order,
          start_date: start_date + 1.day,
          end_date:   end_date + 2.days,
          status:     "scheduled"
        )

        conflicting_order_unit = build(
          :order_unit,
          order: new_order,
          unit: unit,
          placed_on: new_order.start_date
        )

        expect(conflicting_order_unit).not_to be_valid
        expect(conflicting_order_unit.errors[:base]).to include("Unit is already booked for that date range")
      end
    end
  end

  describe "#rental_days" do
    it "uses removed_on when present" do
      order_unit = build(
        :order_unit,
        placed_on: Date.today,
        removed_on: Date.today + 2.days
      )

      expect(order_unit.rental_days).to eq(3)
    end

    it "falls back to order.end_date when removed_on is nil" do
      order = create(:order, start_date: Date.today, end_date: Date.today + 4.days)
      order_unit = build(
        :order_unit,
        order: order,
        placed_on: order.start_date,
        removed_on: nil
      )

      expect(order_unit.rental_days).to eq(5)
    end
  end
end
