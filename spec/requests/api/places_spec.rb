require "rails_helper"

RSpec.describe "Api::Places", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /api/places/autocomplete" do
    it "returns predictions from Google" do
      client = instance_double(Geocoding::GoogleClient)
      allow(Geocoding::GoogleClient).to receive(:new).and_return(client)
      allow(client).to receive(:autocomplete).with("farm").and_return([
        { description: "Farm Site", place_id: "abc123" }
      ])

      get api_places_autocomplete_path, params: { query: "farm" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["suggestions"]).to eq([ { "description" => "Farm Site", "place_id" => "abc123" } ])
    end
  end

  describe "GET /api/places/details" do
    it "returns structured details for a place" do
      client = instance_double(Geocoding::GoogleClient)
      allow(Geocoding::GoogleClient).to receive(:new).and_return(client)
      allow(client).to receive(:place_details).with("abc123").and_return(
        {
          "street" => "123 Main St",
          "city" => "La Farge",
          "state" => "WI",
          "postal_code" => "54639",
          "lat" => 43.6,
          "lng" => -90.6
        }
      )

      get api_places_details_path, params: { place_id: "abc123" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["street"]).to eq("123 Main St")
      expect(body["postal_code"]).to eq("54639")
    end

    it "returns 422 when no details found" do
      client = instance_double(Geocoding::GoogleClient)
      allow(Geocoding::GoogleClient).to receive(:new).and_return(client)
      allow(client).to receive(:place_details).and_return(nil)

      get api_places_details_path, params: { place_id: "missing" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
