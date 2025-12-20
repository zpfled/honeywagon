FactoryBot.define do
  factory :dump_site do
    association :company
    association :location, factory: [ :location, :dump_site ]
    sequence(:name) { |n| "Dump Site #{n}" }
  end
end
