FactoryBot.define do
  factory :unit do
    unit_type do
      UnitType.find_or_create_by!(slug: "standard") do |ut|
        ut.name   = "Standard Unit"
        ut.prefix = "S"
      end
    end
    company { unit_type.company || association(:company) }

    manufacturer { "TestCo" }
    status { "available" }

    trait :standard do
      unit_type do
        UnitType.find_or_create_by!(slug: "standard") do |ut|
          ut.name   = "Standard Unit"
          ut.prefix = "S"
        end
      end
      company { unit_type.company }
    end

    trait :ada do
      unit_type do
        UnitType.find_or_create_by!(slug: "ada") do |ut|
          ut.name   = "ADA Accessible Unit"
          ut.prefix = "A"
        end
      end
      company { unit_type.company }
    end

    trait :handwash do
      unit_type do
        UnitType.find_or_create_by!(slug: "handwash") do |ut|
          ut.name   = "Handwash Station"
          ut.prefix = "H"
        end
      end
      company { unit_type.company }
    end
  end
end
