require "rails_helper"

RSpec.describe "Company settings", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "PATCH /company" do
    it "creates a unit type scoped to the signed-in user's company" do
      expect do
        patch company_path, params: { unit_type: { name: "VIP Suite", prefix: "VIP" } }
      end.to change { user.company.unit_types.count }.by(1)

      expect(response).to redirect_to(edit_company_path)
    end

    it "creates a rate plan for a company unit type" do
      unit_type = create(:unit_type, company: user.company)

      expect do
        patch company_path, params: {
          rate_plan: {
            unit_type_id: unit_type.id,
            service_schedule: "weekly",
            billing_period: "monthly",
            price_cents: "120.00",
            active: "1"
          }
        }
      end.to change { unit_type.rate_plans.count }.by(1)

      expect(response).to redirect_to(edit_company_path)
    end

    it "re-renders with an error when rate plan price is invalid" do
      unit_type = create(:unit_type, company: user.company)

      expect do
        patch company_path, params: {
          rate_plan: {
            unit_type_id: unit_type.id,
            service_schedule: "weekly",
            billing_period: "monthly",
            price_cents: "not-a-number",
            active: "1"
          }
        }
      end.not_to change { unit_type.rate_plans.count }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to match(/not a number/i)
    end
  end
end
