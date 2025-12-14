FactoryBot.define do
  factory :trailer do
    association :company
    sequence(:name) { |n| "Trailer #{n}" }
    sequence(:identifier) { |n| "TRL-#{n}" }
    capacity_spots { 6 }
  end
end
