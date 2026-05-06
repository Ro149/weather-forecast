Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get  "forecast/new",  to: "forecasts#new",  as: :new_forecast
  get  "forecast/show", to: "forecasts#show", as: :forecast
  root "forecasts#new"
end
