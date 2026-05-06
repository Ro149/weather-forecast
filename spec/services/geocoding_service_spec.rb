# frozen_string_literal: true

require "rails_helper"

RSpec.describe GeocodingService do
  let(:address) { "1600 Pennsylvania Ave, Washington DC" }

  describe "#call" do
    context "when Nominatim returns a result" do
      before do
        stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/search})
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: nominatim_success_body.to_json
          )
      end

      it "returns a normalized location hash" do
        result = described_class.new(address).call

        expect(result).to include(
          lat: 38.8977,
          lon: -77.0365,
          zip: "20500",
          city: "Washington",
          state: "District of Columbia",
          country: "United States",
          display_name: "The White House"
        )
      end
    end

    context "when Nominatim returns an empty array" do
      before do
        stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/search})
          .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns nil" do
        expect(described_class.new("nowhere-xyz-12345").call).to be_nil
      end
    end

    context "when the HTTP response is not valid JSON" do
      before do
        stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/search})
          .to_return(status: 502, body: "Bad Gateway")
      end

      it "returns nil" do
        expect(described_class.new(address).call).to be_nil
      end
    end
  end

  def nominatim_success_body
    [
      {
        "lat" => "38.8977",
        "lon" => "-77.0365",
        "display_name" => "The White House",
        "address" => {
          "postcode" => "20500",
          "city" => "Washington",
          "state" => "District of Columbia",
          "country" => "United States"
        }
      }
    ]
  end
end
