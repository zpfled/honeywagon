require "rails_helper"

RSpec.describe "Orders schedule action", type: :request do
  describe "POST /orders/:id/schedule" do
    it "transitions a draft order to scheduled and generates service events even if types missing" do
      ServiceEventType.delete_all
      order = create(:order, status: "draft", start_date: Date.today, end_date: Date.today + 7.days)

      post schedule_order_path(order)

      expect(response).to redirect_to(order_path(order))
      expect(order.reload.status).to eq("scheduled")
      expect(order.service_events).not_to be_empty
    end
  end
end
