FactoryBot.define do
  factory :expense do
    association :company
    name { 'Fuel' }
    category { 'fuel' }
    cost_type { 'per_mile' }
    base_amount { 10 }
    package_size { nil }
    applies_to { ['all'] }
    active { true }
  end
end
