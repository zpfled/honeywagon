require "rails_helper"

RSpec.describe Company, type: :model do

  #TODO: Add simple tests for validations & associations

  describe "#fuel_price_per_gallon" do
    it "returns nil when cents are blank" do
      company = build(:company, fuel_price_per_gal_cents: nil)

      expect(company.fuel_price_per_gallon).to be_nil
    end

    it "returns dollars when cents are present" do
      company = build(:company, fuel_price_per_gal_cents: 345)

      expect(company.fuel_price_per_gallon).to eq(3.45)
    end
  end

  describe "#fuel_price_per_gallon=" do
    it "stores cents when given a numeric value" do
      company = build(:company)

      company.fuel_price_per_gallon = "4.01"

      expect(company.fuel_price_per_gal_cents).to eq(401)
    end

    it "clears cents when nil is provided" do
      company = build(:company, fuel_price_per_gal_cents: 500)

      company.fuel_price_per_gallon = nil

      expect(company.fuel_price_per_gal_cents).to be_nil
    end
  end
end
