FactoryBot.define do
  factory :rate_plan do
    association :unit_type

    service_schedule { 'weekly' }        # weekly | biweekly | event
    billing_period   { 'monthly' }        # monthly | per_event
    price_cents      { 14_000 }
    active           { true }

    trait :weekly do
      service_schedule { 'weekly' }
      billing_period   { 'monthly' }
    end

    trait :biweekly do
      service_schedule { 'biweekly' }
      billing_period   { 'monthly' }
      price_cents      { 12_000 }
    end

    trait :event do
      service_schedule { 'event' }
      billing_period   { 'per_event' }
      price_cents      { 11_000 }
    end

    trait :inactive do
      active { false }
    end
  end
end
