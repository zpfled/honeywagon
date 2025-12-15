require "rails_helper"

RSpec.describe Geocoding::GoogleClient do
  describe "#autocomplete" do
    let(:client) { described_class.new(api_key: "test") }

    it "normalizes predictions from the suggestions array" do
      body = {
        "suggestions" => [
          {
            "placePrediction" => {
              "placeId" => "place-123",
              "text" => { "text" => "Main Text" },
              "structuredFormat" => {
                "mainText" => { "text" => "Main Text" },
                "secondaryText" => { "text" => "Town, WI" }
              }
            }
          },
          {
            "placePrediction" => {
              "placeId" => "place-456",
              "structuredFormat" => {
                "mainText" => { "text" => "Other St" },
                "secondaryText" => { "text" => "City, WI" }
              }
            }
          }
        ]
      }

      allow(client).to receive(:request_json).and_return(body)

      results = client.autocomplete("Main")

      expect(results).to contain_exactly(
        { description: "Main Text", place_id: "place-123" },
        { description: "Other St, City, WI", place_id: "place-456" }
      )
    end
  end
end
