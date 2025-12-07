require "rails_helper"

RSpec.describe Unit, type: :model do
  let(:unit_type) { create(:unit_type, :standard) }

  describe "associations" do
    it "belongs to a unit_type" do
      unit = Unit.new(unit_type: unit_type)

      expect(unit.unit_type).to eq(unit_type)
    end
  end

  describe "before_create" do
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


# spec/models/unit_serial_spec.rb
require "rails_helper"

RSpec.describe Unit, type: :model do
  let(:standard_type) do
    UnitType.create!(
      name: "Standard Unit",
      slug: "standard",
      prefix: "S",
      next_serial: 1
    )
  end

  let(:ada_type) do
    UnitType.create!(
      name: "ADA Accessible Unit",
      slug: "ada",
      prefix: "A",
      next_serial: 1
    )
  end

  def build_unit(unit_type)
    Unit.create!(
      unit_type: unit_type,
      manufacturer: "TestCo",
      status: "available"
    )
  end

  describe "serial assignment" do
    it "assigns serial with prefix and increments per type" do
      u1 = build_unit(standard_type)
      u2 = build_unit(standard_type)

      expect(u1.serial).to eq("S-1")
      expect(u2.serial).to eq("S-2")

      standard_type.reload
      expect(standard_type.next_serial).to eq(3)
    end

    it "keeps sequences independent per unit_type" do
      s1 = build_unit(standard_type)
      a1 = build_unit(ada_type)
      s2 = build_unit(standard_type)
      a2 = build_unit(ada_type)

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
  end
end
