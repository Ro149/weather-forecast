# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeatherService do
  let(:lat) { 38.8977 }
  let(:lon) { -77.0365 }

  describe "#call" do
    context "when Open-Meteo returns forecast data" do
      before do
        stub_request(:get, %r{\Ahttps://api\.open-meteo\.com/v1/forecast})
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: open_meteo_success_body.to_json
          )
      end

      it "returns parsed current weather and a 7-day forecast" do
        result = described_class.new(lat, lon).call

        expect(result).to include(
          current_temp: 72,
          feels_like: 70,
          humidity: 55,
          wind_speed: 8,
          condition: "Mainly Clear",
          icon: "🌤️",
          today_high: 75,
          today_low: 62,
          timezone: "America/New_York"
        )
        expect(result[:forecast].size).to eq(7)
        expect(result[:forecast].first).to include(
          high: 75,
          low: 62,
          weather_code: 1,
          condition: "Mainly Clear"
        )
      end
    end

    context "when Open-Meteo returns an error payload" do
      before do
        stub_request(:get, %r{\Ahttps://api\.open-meteo\.com/v1/forecast})
          .to_return(
            status: 200,
            body: { "error" => true, "reason" => "invalid" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(described_class.new(lat, lon).call).to be_nil
      end
    end

    context "when the HTTP response is not valid JSON" do
      before do
        stub_request(:get, %r{\Ahttps://api\.open-meteo\.com/v1/forecast})
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "returns nil" do
        expect(described_class.new(lat, lon).call).to be_nil
      end
    end
  end

  def open_meteo_success_body
    days = (0...7).map { |i| (Date.new(2026, 5, 6) + i).strftime("%Y-%m-%d") }
    {
      "timezone" => "America/New_York",
      "current" => {
        "temperature_2m" => 72.4,
        "apparent_temperature" => 70.2,
        "weather_code" => 1,
        "wind_speed_10m" => 7.9,
        "relative_humidity_2m" => 55,
        "precipitation" => 0.0
      },
      "current_units" => {},
      "daily" => {
        "time" => days,
        "temperature_2m_max" => Array.new(7, 75.2),
        "temperature_2m_min" => Array.new(7, 62.1),
        "weather_code" => Array.new(7, 1),
        "precipitation_probability_max" => Array.new(7, 20),
        "precipitation_sum" => Array.new(7, 0.0)
      }
    }
  end
end
