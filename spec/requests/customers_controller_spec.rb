require 'rails_helper'

RSpec.describe "CustomersController", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /customers/new" do
    it "renders the new form" do
      get new_customer_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Customer")
    end
  end

  describe "POST /customers" do
    it "creates a customer and redirects to new order" do
      params = { customer: { business_name: "ACME Inc", billing_email: "acme@example.com" } }

      expect {
        post customers_path, params: params
      }.to change { Customer.count }.by(1)

      expect(response).to redirect_to(new_order_path(customer_id: Customer.last.id))
      follow_redirect!
      expect(response.body).to include("Customer created.")
    end

    it "re-renders form on validation failure" do
      params = { customer: { business_name: "", billing_email: "" } }

      expect {
        post customers_path, params: params
      }.not_to change { Customer.count }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("error")
    end
  end
end
