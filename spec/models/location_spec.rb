require "rails_helper"

RSpec.describe Location, type: :model do
  describe "#full_address" do
    it "combines street, city, state, and zip with commas" do
      location = Location.new(
        street: "123 Main St",
        city:   "La Farge",
        state:  "WI",
        zip:    "54639"
      )

      expect(location.full_address).to eq("123 Main St, La Farge, WI, 54639")
    end

    it "skips blank parts when building the address" do
      location = Location.new(
        street: "123 Main St",
        city:   nil,
        state:  "WI",
        zip:    nil
      )

      expect(location.full_address).to eq("123 Main St, WI")
    end

    it "returns an empty string when everything is blank" do
      location = Location.new(
        street: nil,
        city:   nil,
        state:  nil,
        zip:    nil
      )

      expect(location.full_address).to eq("")
    end
  end

  describe ".dump_sites" do
    it "returns only locations marked as dump_site" do
      dump_site = Location.create!(street: "Plant Rd",  dump_site: true)
      job_site  = Location.create!(street: "Job Site",  dump_site: false)

      result = Location.dump_sites

      expect(result).to include(dump_site)
      expect(result).not_to include(job_site)
    end
  end

  describe ".job_sites" do
    it "returns only locations not marked as dump_site" do
      dump_site = Location.create!(street: "Plant Rd",  dump_site: true)
      job_site  = Location.create!(street: "Job Site",  dump_site: false)

      result = Location.job_sites

      expect(result).to include(job_site)
      expect(result).not_to include(dump_site)
    end
  end

  describe "#dump_site?" do
    it "is true when dump_site attribute is true" do
      location = Location.new(dump_site: true)

      expect(location.dump_site?).to be(true)
    end

    it "is false when dump_site attribute is false or nil" do
      location_false = Location.new(dump_site: false)
      location_nil   = Location.new(dump_site: nil)

      expect(location_false.dump_site?).to be(false)
      expect(location_nil.dump_site?).to be(false)
    end
  end

  describe "geocoding" do
    it "looks up coordinates when missing" do
      allow(GoogleMaps).to receive(:api_key).and_return("test-key")
      client = instance_double(Geocoding::GoogleClient, geocode: { lat: 43.5, lng: -90.6 })
      allow(Geocoding::GoogleClient).to receive(:new).and_return(client)

      location = Location.create!(street: "123 Main St", city: "La Farge", state: "WI", zip: "54639")

      expect(location.lat).to eq(43.5)
      expect(location.lng).to eq(-90.6)
    end

    it "skips geocoding when API key missing" do
      allow(GoogleMaps).to receive(:api_key).and_return(nil)
      expect(Geocoding::GoogleClient).not_to receive(:new)

      location = Location.create!(street: "123 Main St", city: "La Farge", state: "WI")
      expect(location.lat).to be_nil
    end
  end
end
