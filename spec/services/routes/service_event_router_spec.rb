require "rails_helper"

RSpec.describe Routes::ServiceEventRouter do
  let(:company) { create(:company) }
  let!(:truck) { create(:truck, company: company) }

  describe "#call" do
    it "chooses the smallest trailer that can accommodate delivery requirements" do
      small_trailer = create(:trailer, company: company, capacity_spots: 2)
      large_trailer = create(:trailer, company: company, capacity_spots: 6)

      order = create(:order, company: company)
      unit_type = create(:unit_type, :standard, company: company)
      create(:order_line_item, order: order, unit_type: unit_type, quantity: 4)
      event = nil

      Routes::ServiceEventRouter.without_auto_assignment do
        event = create(:service_event, :delivery, order: order, scheduled_on: Date.today + 1.day, route: nil)
      end

      described_class.new(event).call

      expect(event.reload.route.trailer).to eq(large_trailer)
      expect(event.route.trailer).not_to eq(small_trailer)
    end
  end
end
