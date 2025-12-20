require "rails_helper"

RSpec.describe Unit, type: :model do
  let(:company) { create(:company) }
  let(:dispatcher) { create(:user, company: company) }
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
    describe ".overlapping_between" do
      let(:start_date) { Date.today }
      let(:end_date)   { Date.today + 3.days }

      it "returns units with assignments that overlap the supplied window" do
        overlapping_unit = create(:unit, status: "available", company: company, unit_type: unit_type)
        other_unit = create(:unit, status: "available", company: company, unit_type: unit_type)

        blocking_order = create(
          :order,
          company: company,
          created_by: dispatcher,
          start_date: start_date - 1.day,
          end_date: end_date + 1.day,
          status: "scheduled"
        )
        create(:order_unit, order: blocking_order, unit: overlapping_unit, placed_on: blocking_order.start_date)

        result = Unit.overlapping_between(start_date, end_date)

        expect(result).to include(overlapping_unit)
        expect(result).not_to include(other_unit)
      end

      it "respects blocking statuses and inclusive boundaries" do
        scheduled_unit = create(:unit, status: "available", company: company, unit_type: unit_type)
        draft_unit = create(:unit, status: "available", company: company, unit_type: unit_type)
        completed_unit = create(:unit, status: "available", company: company, unit_type: unit_type)

        scheduled_order = create(
          :order,
          company: company,
          created_by: dispatcher,
          start_date: start_date,
          end_date: end_date,
          status: "scheduled"
        )
        create(:order_unit, order: scheduled_order, unit: scheduled_unit, placed_on: scheduled_order.start_date)

        draft_order = create(
          :order,
          company: company,
          created_by: dispatcher,
          start_date: start_date - 2.days,
          end_date: end_date + 2.days,
          status: "draft"
        )
        create(:order_unit, order: draft_order, unit: draft_unit, placed_on: draft_order.start_date)

        completed_order = create(
          :order,
          company: company,
          created_by: dispatcher,
          start_date: start_date - 4.days,
          end_date: start_date - 1.day,
          status: "completed"
        )
        create(:order_unit, order: completed_order, unit: completed_unit, placed_on: completed_order.start_date)

        result = Unit.overlapping_between(start_date, end_date)

        expect(result).to include(scheduled_unit)
        expect(result).not_to include(draft_unit)
        expect(result).not_to include(completed_unit)
      end
    end

    describe ".available_between" do
      let(:start_date) { Date.today }
      let(:end_date)   { Date.today + 3.days }

      it "returns units that have no blocking overlap and are not retired or maintenance" do
        # u1: maintenance, no orders → excluded from availability
        u1 = create(:unit, status: "maintenance", company: company, unit_type: unit_type)

        # u2: available, on a scheduled order overlapping the window → excluded
        u2 = create(:unit, status: "available", company: company, unit_type: unit_type)
        blocking_order = create(
          :order,
          company: company,
          created_by: dispatcher,
          start_date: start_date - 1.day,
          end_date:   end_date + 1.day,
          status:     "scheduled"
        )
        create(:order_unit, order: blocking_order, unit: u2, placed_on: blocking_order.start_date)

        # u3: available, order ends before window → included
        u3 = create(:unit, status: "available", company: company, unit_type: unit_type)
        past_order = create(
          :order,
          company: company,
          created_by: dispatcher,
          start_date: start_date - 10.days,
          end_date:   start_date - 5.days,
          status:     "completed"
        )
        create(:order_unit, order: past_order, unit: u3, placed_on: past_order.start_date)

        # u4: available, draft order overlapping → still available
        u4 = create(:unit, status: "available", company: company, unit_type: unit_type)
        draft_order = create(
          :order,
          company: company,
          created_by: dispatcher,
          start_date: start_date,
          end_date:   end_date,
          status:     "draft"
        )
        create(:order_unit, order: draft_order, unit: u4, placed_on: draft_order.start_date)

        # u5: retired, no orders → excluded because retired
        u5 = create(:unit, status: "retired", company: company, unit_type: unit_type)

        result = Unit.available_between(start_date, end_date)

        expect(result).to include(u3, u4)
        expect(result).not_to include(u1, u2, u5)
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
