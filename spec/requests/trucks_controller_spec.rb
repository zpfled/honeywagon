require 'rails_helper'

RSpec.describe "TrucksController", type: :request do
  let(:user) { create(:user) }
  let!(:truck) { create(:truck, company: user.company) }

  before { sign_in user }

  describe "GET /trucks/:id/edit" do
    it "renders the edit form" do
      get edit_truck_path(truck)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(truck.name)
    end
  end

  describe "PATCH /trucks/:id" do
    it "updates the truck on success" do
      params = { truck: { name: "Updated Truck" } }

      patch truck_path(truck), params: params

      expect(response).to redirect_to(edit_company_path)
      expect(truck.reload.name).to eq("Updated Truck")
    end

    it "re-renders edit on validation failure" do
      params = { truck: { name: "" } }

      patch truck_path(truck), params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("error")
    end
  end
end
