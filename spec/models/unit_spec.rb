require "rails_helper"

RSpec.describe Unit, type: :model do
  let(:unit_type) { create(:unit_type, :standard) }

  describe "associations" do
    it "belongs to a unit_type" do
      unit = Unit.new(unit_type: unit_type)

      expect(unit.unit_type).to eq(unit_type)
    end
  end

  describe "before_validation" do
    describe "serial assignment" do
      let!(:standard_type) { create(:unit_type, :standard, next_serial: 1) }
      let!(:ada_type)      { create(:unit_type, :ada,      next_serial: 1) }

      it "assigns serial with prefix and increments per type" do
        u1 = create(:unit, unit_type: standard_type)
        u2 = create(:unit, unit_type: standard_type)
        a1 = create(:unit, unit_type: ada_type)

        expect(u1.serial).to eq("S-1")
        expect(u2.serial).to eq("S-2")
        expect(a1.serial).to eq("A-1")
      end

      it "keeps sequences independent per unit_type" do
        s1 = create(:unit, :standard)
        a1 = create(:unit, :ada)
        s2 = create(:unit, :standard)
        a2 = create(:unit, :ada)

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