FactoryBot.define do
  factory :order_unit do
    association :order
    association :unit

    placed_on  { order.start_date }
    removed_on { nil }
    daily_rate_cents { nil }
    billing_period { 'monthly' }
  end
end
