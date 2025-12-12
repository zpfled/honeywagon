FactoryBot.define do
  factory :order_line_item do
    association :order
    association :unit_type
    association :rate_plan

    service_schedule { rate_plan&.service_schedule || RatePlan::SERVICE_SCHEDULES[:weekly] }
    billing_period   { rate_plan&.billing_period   || 'monthly' }

    quantity         { 1 }
    unit_price_cents { rate_plan&.price_cents || 14_000 }
    subtotal_cents   { quantity * unit_price_cents }
  end
end
