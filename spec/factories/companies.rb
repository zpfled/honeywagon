FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Test Company #{n}" }
    setup_completed { true }

    trait :incomplete do
      setup_completed { false }
    end
  end
end
