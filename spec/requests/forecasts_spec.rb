# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Forecasts", type: :request do
  describe "GET /forecast/new" do
    it "returns success" do
      get new_forecast_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /forecast/show" do
    context "without an address" do
      it "redirects to new with a flash alert" do
        get forecast_path
        expect(response).to redirect_to(new_forecast_path)
        expect(flash[:alert]).to eq("Please enter an address.")
      end
    end

    context "with a blank address" do
      it "redirects to new with a flash alert" do
        get forecast_path, params: { address: "   " }
        expect(response).to redirect_to(new_forecast_path)
        expect(flash[:alert]).to eq("Please enter an address.")
      end
    end

    context "when geocoding finds no location" do
      before do
        stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/search})
          .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })
      end

      it "redirects with a helpful message" do
        get forecast_path, params: { address: "nonexistent-xyz-99999" }
        expect(response).to redirect_to(new_forecast_path)
        expect(flash[:alert]).to include("Could not find a location")
      end
    end

    context "when geocoding and weather succeed" do
      before do
        stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/search})
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: nominatim_body.to_json
          )
        stub_request(:get, %r{\Ahttps://api\.open-meteo\.com/v1/forecast})
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: open_meteo_body.to_json
          )
      end

      it "renders the forecast" do
        get forecast_path, params: { address: "Test City" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("72") # current temp from stub
      end
    end

    context "when weather API returns an error payload" do
      before do
        stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/search})
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: nominatim_body.to_json
          )
        stub_request(:get, %r{\Ahttps://api\.open-meteo\.com/v1/forecast})
          .to_return(
            status: 200,
            body: { "error" => true }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "redirects with a flash alert" do
        get forecast_path, params: { address: "Test City" }
        expect(response).to redirect_to(new_forecast_path)
        expect(flash[:alert]).to include("Could not retrieve weather")
      end
    end
  end

  def nominatim_body
    [
      {
        "lat" => "40.0",
        "lon" => "-75.0",
        "display_name" => "Test",
        "address" => { "postcode" => "19101", "city" => "Philadelphia", "country" => "US" }
      }
    ]
  end

  def open_meteo_body
    days = (0...7).map { |i| (Date.new(2026, 5, 6) + i).strftime("%Y-%m-%d") }
    {
      "timezone" => "America/New_York",
      "current" => {
        "temperature_2m" => 72.0,
        "apparent_temperature" => 70.0,
        "weather_code" => 0,
        "wind_speed_10m" => 5.0,
        "relative_humidity_2m" => 40,
        "precipitation" => 0.0
      },
      "daily" => {
        "time" => days,
        "temperature_2m_max" => Array.new(7, 80.0),
        "temperature_2m_min" => Array.new(7, 60.0),
        "weather_code" => Array.new(7, 0),
        "precipitation_probability_max" => Array.new(7, 0),
        "precipitation_sum" => Array.new(7, 0.0)
      }
    }
  end
end
