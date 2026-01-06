FactoryBot.define do
  factory :unit_type do
    association :company
    sequence(:name) { |n| "Unit Type #{n}" }
    sequence(:slug) { |n| "unit-type-#{n}" }
    prefix { "X" }
    next_serial { 1 }
    delivery_clean_gallons { 5 }
    service_clean_gallons { 7 }
    service_waste_gallons { 10 }
    pickup_clean_gallons { 2 }
    pickup_waste_gallons { 10 }

    trait :standard do
      name  { "Standard Unit" }
      slug  { "standard" }
      prefix { "S" }
      delivery_clean_gallons { 5 }
    end

    trait :ada do
      name  { "ADA Accessible Unit" }
      slug  { "ada" }
      prefix { "A" }
      delivery_clean_gallons { 5 }
    end

    trait :handwash do
      name  { "Handwash Station" }
      slug  { "handwash" }
      prefix { "H" }
      delivery_clean_gallons { 20 }
    end
  end
end
