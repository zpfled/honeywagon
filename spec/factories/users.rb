FactoryBot.define do
  factory :user do
    association :company
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { "dispatcher" }
  end
end
