FactoryBot.define do
  factory :route do
    association :company
    route_date { Date.today }
  end
end
