require "rails_helper"

RSpec.describe UnitType, type: :model do
  describe "associations" do
    it "has many units" do
      assoc = described_class.reflect_on_association(:units)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many rate_plans" do
      assoc = described_class.reflect_on_association(:rate_plans)
      expect(assoc.macro).to eq(:has_many)
    end
  end

  describe "#to_s" do
    it "returns the name" do
      unit_type = UnitType.new(name: "Handicap Accessible")

      expect(unit_type.to_s).to eq("Handicap Accessible")
    end
  end
end
