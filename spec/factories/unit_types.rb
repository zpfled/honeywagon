FactoryBot.define do
  factory :unit_type do
    association :company
    sequence(:name) { |n| "Unit Type #{n}" }
    sequence(:slug) { |n| "unit-type-#{n}" }
    prefix { "X" }
    next_serial { 1 }

    trait :standard do
      name  { "Standard Unit" }
      slug  { "standard" }
      prefix { "S" }
    end

    trait :ada do
      name  { "ADA Accessible Unit" }
      slug  { "ada" }
      prefix { "A" }
    end

    trait :handwash do
      name  { "Handwash Station" }
      slug  { "handwash" }
      prefix { "H" }
    end
  end
end
