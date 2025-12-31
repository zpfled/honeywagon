require "rails_helper"

RSpec.describe OrderPresenter do
  describe "#location_address_line" do
    it "formats street and city/state" do
      location = build_stubbed(:location, street: "123 Main St", city: "Madison", state: "WI")
      order = build_stubbed(:order, location: location)
      presenter = described_class.new(order, view_context: double("view", l: nil))

      expect(presenter.location_address_line).to eq("123 Main St Madison, WI")
    end
  end

  describe "money helpers" do
    let(:order) { build_stubbed(:order) }
    let(:view_context) { double("view", l: nil) }
    let(:presenter) { described_class.new(order, view_context: view_context) }

    it "formats line item price from cents" do
      line_item = double("LineItem", unit_price_cents: 1500, unit_price: nil)
      allow(line_item).to receive(:respond_to?).with(:unit_price_cents).and_return(true)
      allow(line_item).to receive(:respond_to?).with(:unit_price).and_return(true)

      expect(presenter.line_item_unit_price(line_item)).to eq("$15.00")
    end

    it "formats line item subtotal from decimal" do
      line_item = double("LineItem", subtotal_cents: nil, subtotal: 25)
      allow(line_item).to receive(:respond_to?).with(:subtotal_cents).and_return(true)
      allow(line_item).to receive(:respond_to?).with(:subtotal).and_return(true)

      expect(presenter.line_item_subtotal(line_item)).to eq("$25.00")
    end
  end

  describe "#units_count" do
    it "prefers the provided units count when present" do
      order = build_stubbed(:order)
      presenter = described_class.new(order, view_context: double("view", l: nil), units_count: 7)

      expect(presenter.units_count).to eq(7)
    end
  end
end
