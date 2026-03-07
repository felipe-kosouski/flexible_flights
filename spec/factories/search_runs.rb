FactoryBot.define do
  factory :search_run do
    association :search_intent
    state { :initialized }
  end
end
