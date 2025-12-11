FactoryBot.define do
  factory :order_unit do
    order { nil }
    unit { nil }
    placed_on { "2025-12-11" }
    removed_on { "2025-12-11" }
    daily_rate_cents { 1 }
  end
end
