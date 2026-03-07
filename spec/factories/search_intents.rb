FactoryBot.define do
  factory :search_intent do
    association :user
    origin_airport { "JFK" }
    destination_airport { "LHR" }
    earliest_departure { 30.days.from_now.to_date }
    latest_return { 44.days.from_now.to_date }
    min_stay_days { 5 }
    max_stay_days { 10 }
    luggage_requirement { :carry_on }
    max_stops { 1 }
  end
end
