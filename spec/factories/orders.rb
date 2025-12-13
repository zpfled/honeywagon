FactoryBot.define do
  factory :order do
    association :user
    association :customer
    association :location

    external_reference { nil }
    status { "draft" }

    start_date { Date.today }
    end_date   { Date.today + 7.days }

    notes { nil }

    rental_subtotal_cents { 0 }
    delivery_fee_cents    { 0 }
    pickup_fee_cents      { 0 }
    discount_cents        { 0 }
    tax_cents             { 0 }
    total_cents           { 0 }

    trait :scheduled do
      status { "scheduled" }
    end

    trait :active do
      status { "active" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :with_service_events do
      after(:create) do |order|
        create(:service_event, :delivery, order: order, scheduled_on: order.start_date)
        create(:service_event, :pickup,   order: order, scheduled_on: order.end_date)
      end
    end

    trait :with_units do
      transient do
        unit_count { 3 }
      end

      after(:create) do |order, evaluator|
        units = create_list(:unit, evaluator.unit_count)
        units.each do |unit|
          create(:order_unit, order: order, unit: unit, placed_on: order.start_date)
        end
      end
    end
  end
end
