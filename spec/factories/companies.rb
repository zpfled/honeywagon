FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Test Company #{n}" }
  end
end
