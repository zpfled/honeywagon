FactoryBot.define do
  factory :truck do
    association :company
    sequence(:name) { |n| "Truck #{n}" }
    sequence(:number) { |n| "HT-#{n}" }
    clean_water_capacity_gal { 200 }
    septage_capacity_gal { 250 }
  end
end
