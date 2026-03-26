FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    first_name { "Jane" }
    last_name { "Doe" }
    confirmed_at { Time.current }
  end
end
