FactoryBot.define do
  factory :route do
    association :company
    route_date { Date.today }
    truck { association(:truck, company: company) }
    trailer { association(:trailer, company: company) }

    trait :without_trailer do
      trailer { nil }
    end
  end
end
