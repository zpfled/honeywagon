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
      own_order = create(:order, created_by: user, company: user.company)
      other_order = create(:order, company: create(:company), customer: create(:customer, business_name: "Other Co"))

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

  describe "new order form scoping" do
    before { sign_in user }

    it "only lists the current company's unit types in the line item selector" do
      own_type   = create(:unit_type, name: "Own Type", company: user.company)
      other_type = create(:unit_type, name: "Other Type")

      get new_order_path

      expect(response.body).to include(own_type.name)
      expect(response.body).not_to include(other_type.name)
    end

    it "only lists the current company's customers in the customer dropdown" do
      own_customer = create(:customer, business_name: "Own Customer", company: user.company)
      other_customer = create(:customer, business_name: "Other Customer")

      get new_order_path

      expect(response.body).to include(own_customer.display_name)
      expect(response.body).not_to include(other_customer.display_name)
    end

    it "only lists the current company's locations in the location dropdown" do
      own_location = create(:location, label: "Own Site", customer: create(:customer, company: user.company))
      other_location = create(:location, label: "Other Site")

      get new_order_path

      expect(response.body).to include(own_location.display_label)
      expect(response.body).not_to include(other_location.display_label)
    end
  end
end
