FactoryBot.define do
  factory :flight_sample do
    association :search_run
    provider { "test_provider" }
    price_cents { 50_000 }
    currency { "USD" }
    air_time_minutes { 480 }
    layover_time_minutes { 0 }
    stops { 0 }
    airlines { [ "AA" ] }
    luggage_included { false }
    departure_datetime { 30.days.from_now }
    return_datetime { 37.days.from_now }
  end
end
