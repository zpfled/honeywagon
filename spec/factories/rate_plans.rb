FactoryBot.define do
  factory :rate_plan do
    association :company
    unit_type { association(:unit_type, company: company) }

    service_schedule { RatePlan::SERVICE_SCHEDULES[:weekly] }        # weekly | biweekly | event
    billing_period   { 'monthly' }        # monthly | per_event
    price_cents      { 14_000 }
    active           { true }

    trait :weekly do
      service_schedule { RatePlan::SERVICE_SCHEDULES[:weekly] }
      billing_period   { 'monthly' }
    end

    trait :biweekly do
      service_schedule { RatePlan::SERVICE_SCHEDULES[:biweekly] }
      billing_period   { 'monthly' }
      price_cents      { 12_000 }
    end

    trait :event do
      service_schedule { RatePlan::SERVICE_SCHEDULES[:event] }
      billing_period   { 'per_event' }
      price_cents      { 11_000 }
    end

    trait :inactive do
      active { false }
    end

    after(:build) do |plan|
      if plan.unit_type.present?
        plan.company = plan.unit_type.company
      else
        plan.company ||= build(:company)
      end
    end
  end
end
