require "net/http"
require "json"
require "uri"
require "date"

class WeatherService
  OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

  WEATHER_DESCRIPTIONS = {
    0 => "Clear Sky",
    1 => "Mainly Clear",
    2 => "Partly Cloudy",
    3 => "Overcast",
    45 => "Foggy",
    48 => "Depositing Rime Fog",
    51 => "Light Drizzle",
    53 => "Moderate Drizzle",
    55 => "Dense Drizzle",
    61 => "Slight Rain",
    63 => "Moderate Rain",
    65 => "Heavy Rain",
    71 => "Slight Snow",
    73 => "Moderate Snow",
    75 => "Heavy Snow",
    77 => "Snow Grains",
    80 => "Slight Showers",
    81 => "Moderate Showers",
    82 => "Violent Showers",
    85 => "Slight Snow Showers",
    86 => "Heavy Snow Showers",
    95 => "Thunderstorm",
    96 => "Thunderstorm w/ Hail",
    99 => "Thunderstorm w/ Heavy Hail"
  }.freeze

  WEATHER_ICONS = {
    0 => "☀️",
    1 => "🌤️",
    2 => "⛅",
    3 => "☁️",
    45 => "🌫️",
    48 => "🌫️",
    51 => "🌦️",
    53 => "🌦️",
    55 => "🌧️",
    61 => "🌧️",
    63 => "🌧️",
    65 => "🌧️",
    71 => "🌨️",
    73 => "🌨️",
    75 => "❄️",
    77 => "🌨️",
    80 => "🌦️",
    81 => "🌧️",
    82 => "⛈️",
    85 => "🌨️",
    86 => "❄️",
    95 => "⛈️",
    96 => "⛈️",
    99 => "⛈️"
  }.freeze

  def initialize(lat, lon)
    @lat = lat
    @lon = lon
  end

  def call
    uri = URI(OPEN_METEO_URL)
    uri.query = URI.encode_www_form(
      latitude: @lat,
      longitude: @lon,
      current: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,precipitation",
      daily: "temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max,precipitation_sum",
      temperature_unit: "fahrenheit",
      wind_speed_unit: "mph",
      precipitation_unit: "inch",
      timezone: "auto",
      forecast_days: 7
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ca_file = ENV["SSL_CERT_FILE"] if ENV["SSL_CERT_FILE"]
    http.open_timeout = 5
    http.read_timeout = 10

    response = http.get(uri.request_uri)
    data = JSON.parse(response.body)

    return nil if data["error"]

    parse_weather(data)
  rescue => e
    Rails.logger.error("WeatherService error: #{e.class}: #{e.message}")
    nil
  end

  private

  def parse_weather(data)
    current = data["current"]
    daily   = data["daily"]
    units   = data["current_units"] || {}

    {
      current_temp:  current["temperature_2m"].round,
      feels_like:    current["apparent_temperature"].round,
      humidity:      current["relative_humidity_2m"],
      wind_speed:    current["wind_speed_10m"].round,
      precipitation: current["precipitation"],
      weather_code:  current["weather_code"],
      condition:     description(current["weather_code"]),
      icon:          icon(current["weather_code"]),
      today_high:    daily["temperature_2m_max"][0].round,
      today_low:     daily["temperature_2m_min"][0].round,
      timezone:      data["timezone"],
      forecast:      build_forecast(daily)
    }
  end

  def build_forecast(daily)
    (0...7).map do |i|
      {
        date:          Date.parse(daily["time"][i]),
        high:          daily["temperature_2m_max"][i].round,
        low:           daily["temperature_2m_min"][i].round,
        weather_code:  daily["weather_code"][i],
        condition:     description(daily["weather_code"][i]),
        icon:          icon(daily["weather_code"][i]),
        precip_chance: daily["precipitation_probability_max"][i],
        precip_sum:    daily["precipitation_sum"][i]
      }
    end
  end

  def description(code)
    WEATHER_DESCRIPTIONS[code] || "Unknown"
  end

  def icon(code)
    WEATHER_ICONS[code]
  end
end
