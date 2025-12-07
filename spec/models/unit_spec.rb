require "rails_helper"

RSpec.describe Unit, type: :model do
  let(:unit_type) { UnitType.create!(name: "Standard", slug: "standard") }

  describe "associations" do
    it "belongs to a unit_type" do
      unit = Unit.new(unit_type: unit_type)

      expect(unit.unit_type).to eq(unit_type)
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
