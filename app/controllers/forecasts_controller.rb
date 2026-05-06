require "net/http"
require "json"

class ForecastsController < ApplicationController
  def new
  end

  def show
    address = params[:address].to_s.strip

    if address.blank?
      flash[:alert] = "Please enter an address."
      redirect_to new_forecast_path and return
    end
    
    location = GeocodingService.new(address).call

    if location.nil?
      flash[:alert] = "Could not find a location for that address. Please try a more specific address."
      redirect_to new_forecast_path and return
    end

    zip = location[:zip].presence || "#{location[:lat].round(4)},#{location[:lon].round(4)}"
    cache_key = "weather_forecast_v1_#{zip}"

    @from_cache = Rails.cache.exist?(cache_key)

    @weather = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      WeatherService.new(location[:lat], location[:lon]).call
    end

    if @weather.nil?
      flash[:alert] = "Could not retrieve weather data. Please try again."
      redirect_to new_forecast_path and return
    end

    @address = address
    @location = location
    @zip = zip
    @cached_at = @from_cache ? "Cached result (zip: #{zip})" : nil
  end
end
