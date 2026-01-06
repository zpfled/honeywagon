FactoryBot.define do
  factory :service_event do
    association :order
    scheduled_on { Date.today }
    event_type { :service }
    status { :scheduled }
    notes { nil }
    auto_generated { false }
    association :service_event_type, factory: :service_event_type_service
    after(:build) do |event|
      event.user ||= event.order&.created_by || create(:user)
      event.route_date ||= event.route&.route_date || event.scheduled_on
    end

    trait :delivery do
      event_type { :delivery }
      association :service_event_type, factory: :service_event_type_delivery
    end

    trait :service do
      event_type { :service }
      association :service_event_type, factory: :service_event_type_service
    end

    trait :pickup do
      event_type { :pickup }
      association :service_event_type, factory: :service_event_type_pickup
    end

    trait :dump do
      event_type { :dump }
      association :service_event_type, factory: :service_event_type_dump
      association :dump_site
      order { nil }
    end

    trait :refill do
      event_type { :refill }
      association :service_event_type, factory: :service_event_type_refill
      order { nil }
    end

    trait :completed do
      status { :completed }
    end
  end
end
