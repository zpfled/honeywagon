FactoryBot.define do
  factory :route_stop do
    association :route
    association :service_event
    sequence(:position) { |idx| idx }
    status { :scheduled }
    created_by { association(:user, company: route.company) }
    notes { nil }
  end
end
