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

  describe "GET /locations/:id/edit" do
    it "renders the edit modal for a company location" do
      customer = create(:customer, company: user.company)
      location = create(:location, customer: customer)

      get edit_location_path(location)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(location.display_label)
    end

    it "returns not found for locations outside the company" do
      other_location = create(:location)

      get edit_location_path(other_location)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /locations/:id" do
    it "updates coordinates for a company location" do
      customer = create(:customer, company: user.company)
      location = create(:location, customer: customer, lat: nil, lng: nil)

      patch location_path(location), params: {
        location: {
          lat: 43.123456,
          lng: -90.654321
        }
      }

      expect(response).to redirect_to(locations_company_path)
      location.reload
      expect(location.lat.to_f).to eq(43.123456)
      expect(location.lng.to_f).to eq(-90.654321)
    end
  end
end
