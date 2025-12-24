FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Test Company #{n}" }
    setup_completed { true }

    trait :incomplete do
      setup_completed { false }
    end

    trait :with_home_base do
      association :home_base, factory: %i[location standalone]
    end
  end
end
