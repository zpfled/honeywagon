require "rails_helper"

RSpec.describe "/orders", type: :request do
  let(:user) { create(:user) }

  describe "authentication" do
    it "redirects guests to the sign-in page" do
      get orders_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "scoped access" do
    before { sign_in user }

    it "lists only the signed-in user's orders" do
      own_order = create(:order, user: user)
      other_order = create(:order, customer: create(:customer, company_name: "Other Co"))

      get orders_path

      expect(response.body).to include(own_order.customer.display_name)
      expect(response.body).not_to include(other_order.customer.display_name)
    end

    it "prevents access to another user's order" do
      other_order = create(:order)

      get order_path(other_order)

      expect(response).to have_http_status(:not_found)
    end
  end
end
