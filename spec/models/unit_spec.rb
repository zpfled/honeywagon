require "rails_helper"

RSpec.describe Unit, type: :model do
  let(:company) { create(:company) }
  let(:unit_type) { create(:unit_type, :standard, company: company) }

  describe "associations" do
    it "belongs to a unit_type" do
      unit = Unit.new(unit_type: unit_type)

      expect(unit.unit_type).to eq(unit_type)
    end
  end

  describe "before_validation" do
    describe "serial assignment" do
      let!(:standard_type) { create(:unit_type, :standard, next_serial: 1, company: company) }
      let!(:ada_type)      { create(:unit_type, :ada,      next_serial: 1, company: company) }

      it "assigns serial with prefix and increments per type" do
        u1 = create(:unit, unit_type: standard_type)
        u2 = create(:unit, unit_type: standard_type)
        a1 = create(:unit, unit_type: ada_type)

        expect(u1.serial).to eq("S-1")
        expect(u2.serial).to eq("S-2")
        expect(a1.serial).to eq("A-1")
      end

      it "keeps sequences independent per unit_type" do
        s1 = create(:unit, unit_type: standard_type, company: company)
        a1 = create(:unit, unit_type: ada_type, company: company)
        s2 = create(:unit, unit_type: standard_type, company: company)
        a2 = create(:unit, unit_type: ada_type, company: company)

        expect(s1.serial).to eq("S-1")
        expect(s2.serial).to eq("S-2")

        expect(a1.serial).to eq("A-1")
        expect(a2.serial).to eq("A-2")

        expect(standard_type.reload.next_serial).to eq(3)
        expect(ada_type.reload.next_serial).to eq(3)
      end

      it "does not overwrite serial if already set" do
        unit = Unit.create!(
          unit_type: standard_type,
          manufacturer: "TestCo",
          status: "available",
          serial: "CUSTOM-999"
        )

        expect(unit.serial).to eq("CUSTOM-999")
        # next_serial should NOT have moved because we didn't use the generator
        expect(standard_type.reload.next_serial).to eq(1)
      end

      it "enforces serial uniqueness" do
        create(:unit, unit_type: standard_type, serial: "S-99")

        dup = build(:unit, unit_type: standard_type, serial: "S-99")

        expect(dup).not_to be_valid
        expect(dup.errors[:serial]).to include("has already been taken")
      end
    end
  end

  describe 'scopes' do
    describe ".available_between" do
      let(:start_date) { Date.today }
      let(:end_date)   { Date.today + 3.days }

      it "returns units that are available and not booked by overlapping blocking orders" do
        # u1: available, no orders → should be included
        u1 = create(:unit, status: "available", company: company, unit_type: unit_type)

        # u2: available, on a scheduled order overlapping the window → should be excluded
        u2 = create(:unit, status: "available", company: company, unit_type: unit_type)
        blocking_order = create(
          :order,
          start_date: start_date - 1.day,
          end_date:   end_date + 1.day,
          status:     "scheduled"
        )
        create(:order_unit, order: blocking_order, unit: u2, placed_on: blocking_order.start_date)

        # u3: available, on an order that ends before window → should be included
        u3 = create(:unit, status: "available", company: company, unit_type: unit_type)
        past_order = create(
          :order,
          start_date: start_date - 10.days,
          end_date:   start_date - 5.days,
          status:     "completed"
        )
        create(:order_unit, order: past_order, unit: u3, placed_on: past_order.start_date)

        # u4: available, on an order that starts after window → should be included
        u4 = create(:unit, status: "available", company: company, unit_type: unit_type)
        future_order = create(
          :order,
          start_date: end_date + 1.day,
          end_date:   end_date + 5.days,
          status:     "scheduled"
        )
        create(:order_unit, order: future_order, unit: u4, placed_on: future_order.start_date)

        # u5: retired, no orders → excluded because of status
        u5 = create(:unit, status: "retired", company: company, unit_type: unit_type)

        result = Unit.available_between(start_date, end_date)

        expect(result).to include(u1, u3, u4)
        expect(result).not_to include(u2, u5)
      end
    end
  end

  describe "#available?" do
    it "returns true when status is 'available'" do
      unit = Unit.new(unit_type: unit_type, status: "available")

      expect(unit.available?).to be(true)
    end

    it "returns false when status is not 'available'" do
      unit = Unit.new(unit_type: unit_type, status: "rented")

      expect(unit.available?).to be(false)
    end
  end

  describe "#rented?" do
    it "returns true when status is 'rented'" do
      unit = Unit.new(unit_type: unit_type, status: "rented")

      expect(unit.rented?).to be(true)
    end

    it "returns false when status is not 'rented'" do
      unit = Unit.new(unit_type: unit_type, status: "available")

      expect(unit.rented?).to be(false)
    end
  end
end
