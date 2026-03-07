FactoryBot.define do
  factory :analysis_snapshot do
    association :search_run
    price_p25_cents { 40_000 }
    price_p50_cents { 50_000 }
    price_p75_cents { 65_000 }
    route_median_duration_minutes { 480 }
    sample_count { 25 }
    confidence_level { :medium }
    volatility { :low }
  end
end
