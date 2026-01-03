require 'rails_helper'

RSpec.describe "Setup::CompaniesController", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /setup/company" do
    it "renders the setup form" do
      get setup_company_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Company")
    end
  end

  describe "PATCH /setup/company" do
    it "completes setup when valid data provided" do
      params = {
        company: { name: "NewCo" },
        setup: {
          unit_types: [ { name: "Standard", slug: "standard", prefix: "S", quantity: 1 } ],
          customers: [ { first_name: "Jane", last_name: "Doe", business_name: "JD LLC", billing_email: "jane@example.com" } ]
        }
      }

      patch setup_company_path, params: params

      expect(response).to redirect_to(authenticated_root_path)
      expect(user.reload.company.setup_completed).to be(true)
      expect(user.company.unit_types.exists?(slug: "standard")).to be(true)
    end

    it "re-renders form on validation failure" do
      params = {
        company: { name: "" }, # invalid
        setup: { unit_types: [] }
      }

      patch setup_company_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("error")
    end
  end
end
