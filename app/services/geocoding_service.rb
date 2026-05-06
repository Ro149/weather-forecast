require "net/http"
require "json"
require "uri"

class GeocodingService
  NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

  def initialize(address)
    @address = address
  end

  def call
    uri = URI(NOMINATIM_URL)
    uri.query = URI.encode_www_form(
      q: @address,
      format: "json",
      addressdetails: 1,
      limit: 1
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ca_file = ENV["SSL_CERT_FILE"] if ENV["SSL_CERT_FILE"]
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "WeatherForecastApp/1.0 (rails-assessment)"
    request["Accept"] = "application/json"
    request["Accept-Language"] = "en"

    response = http.request(request)
    data = JSON.parse(response.body)

    return nil if data.empty?
    result = data.first
    address = result["address"] || {}

    {
      lat: result["lat"].to_f,
      lon: result["lon"].to_f,
      zip: address["postcode"],
      city: address["city"] || address["town"] || address["village"] || address["county"],
      state: address["state"],
      country: address["country"],
      display_name: result["display_name"]
    }
  rescue => e
    Rails.logger.error("GeocodingService error: #{e.class}: #{e.message}")
    nil
  end
end
