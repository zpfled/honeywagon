FactoryBot.define do
  factory :service_event do
    association :order
    scheduled_on { Date.today }
    event_type { :delivery }
    status { :planned }
    notes { nil }

    trait :delivery do
      event_type { :delivery }
    end

    trait :service do
      event_type { :service }
    end

    trait :pickup do
      event_type { :pickup }
    end

    trait :completed do
      status { :completed }
    end
  end
end
