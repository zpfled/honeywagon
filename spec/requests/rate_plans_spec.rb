require "rails_helper"

RSpec.describe "/rate_plans", type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }

  before { sign_in user }

  describe "GET /rate_plans/new" do
    it "requires a unit type" do
      get new_rate_plan_path

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /rate_plans" do
    it "creates a plan scoped to the company" do
      unit_type = create(:unit_type, company: company)

      expect do
        post rate_plans_path, params: {
          rate_plan: {
            unit_type_id: unit_type.id,
            service_schedule: RatePlan::SERVICE_SCHEDULES[:weekly],
            billing_period: "monthly",
            price: "120.00"
          }
        }
      end.to change(RatePlan, :count).by(1)

      expect(response).to redirect_to(new_order_path)
      expect(RatePlan.last.unit_type).to eq(unit_type)
    end

    it "rejects plans for other companies" do
      other_unit_type = create(:unit_type)

      expect do
        post rate_plans_path, params: {
          rate_plan: {
            unit_type_id: other_unit_type.id,
            service_schedule: RatePlan::SERVICE_SCHEDULES[:weekly],
            billing_period: "monthly",
            price: "120.00"
          }
        }
      end.not_to change(RatePlan, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
