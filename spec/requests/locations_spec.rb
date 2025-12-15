require "rails_helper"

RSpec.describe "/locations", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /locations/new" do
    it "requires a customer" do
      get new_location_path

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renders the modal when customer is provided" do
      customer = create(:customer, company: user.company)

      get new_location_path(customer_id: customer.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer.display_name)
    end
  end

  describe "POST /locations" do
    it "creates a location for the current company's customer" do
      customer = create(:customer, company: user.company)

      expect do
        post locations_path, params: {
          location: {
            customer_id: customer.id,
            label: "New Job Site",
            street: "123 Main St",
            city: "La Farge",
            state: "WI",
            zip: "54639"
          }
        }
      end.to change { customer.locations.count }.by(1)

      location = customer.locations.order(:created_at).last
      expect(response).to redirect_to(new_order_path(customer_id: customer.id, location_id: location.id))
    end

    it "rejects locations for customers outside the company" do
      other_customer = create(:customer)

      expect do
        post locations_path, params: {
          location: {
            customer_id: other_customer.id,
            label: "Bad Site"
          }
        }
      end.not_to change(Location, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
