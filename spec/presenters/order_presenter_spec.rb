require "rails_helper"

RSpec.describe OrderPresenter do
  subject(:presenter) do
    described_class.new(order, view_context: view_context)
  end

  let(:view_context) { instance_double(ActionView::Base) }

  describe "#status_badge" do
    let(:order) { build_stubbed(:order, status: "scheduled") }

    it "renders the status through the view context" do
      expect(view_context).to receive(:content_tag).with(
        :span,
        "Scheduled",
        hash_including(class: include("bg-blue-100 text-blue-800 ring-blue-300"))
      )

      presenter.status_badge
    end
  end

  describe "#start_date" do
    let(:order) { build_stubbed(:order, start_date: Date.new(2024, 1, 5)) }

    it "returns localized value when available" do
      allow(view_context).to receive(:l).with(order.start_date).and_return("January 5, 2024")

      expect(presenter.start_date).to eq("January 5, 2024")
    end

    it "falls back to to_s when localization raises I18n::ArgumentError" do
      allow(view_context).to receive(:l).and_raise(I18n::ArgumentError)

      expect(presenter.start_date).to eq(order.start_date.to_s)
    end

    it "returns the order value string when the date is blank" do
      blank_order = build_stubbed(:order, start_date: nil)
      presenter = described_class.new(blank_order, view_context: view_context)

      expect(presenter.start_date).to eq("")
    end
  end

  describe "#line_items_subtotal_cents" do
    let(:view_context) { instance_double(ActionView::Base, content_tag: nil, l: nil) }
    let(:order) { create(:order) }

    before do
      create(:order_line_item, order: order, unit_price_cents: 2_000, quantity: 1)
      create(:order_line_item, order: order, unit_price_cents: 3_000, quantity: 2)
      order.reload
    end

    it "sums subtotal_cents via SQL when association is not loaded" do
      expect(order.order_line_items).not_to be_loaded
      expect(presenter.line_items_subtotal_cents).to eq(8_000)
    end
  end

  describe "#line_items_subtotal_currency" do
    let(:order) { build_stubbed(:order) }

    it "returns a placeholder when no subtotal exists" do
      expect(presenter.line_items_subtotal_currency).to eq("—")
    end
  end

  describe "#line_item_unit_price" do
    let(:order) { build_stubbed(:order) }

    it "formats unit_price_cents when present" do
      line_item = double(:line_item, unit_price_cents: 1_250, subtotal_cents: nil)
      allow(line_item).to receive(:respond_to?) do |method_name, *_args|
        method_name == :unit_price_cents
      end

      allow(view_context).to receive(:l)
      expect(presenter.line_item_unit_price(line_item)).to eq("$12.50")
    end
  end
end
