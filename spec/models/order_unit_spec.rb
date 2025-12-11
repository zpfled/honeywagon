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
        removed_on: Date.yesterday
      )

      expect(order_unit).not_to be_valid
      expect(order_unit.errors[:removed_on]).to include("must be on or after placed_on")
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
