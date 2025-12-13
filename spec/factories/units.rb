FactoryBot.define do
  factory :unit do
    company { association(:company) }
    unit_type { association(:unit_type, :standard, company: company) }

    manufacturer { "TestCo" }
    status { "available" }

    trait :standard do
      unit_type { association(:unit_type, :standard, company: company) }
    end

    trait :ada do
      unit_type { association(:unit_type, :ada, company: company) }
    end

    trait :handwash do
      unit_type { association(:unit_type, :handwash, company: company) }
    end
  end
end
