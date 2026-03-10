FactoryBot.define do
  factory :service_event do
    association :order
    scheduled_on { Date.today }
    event_type { :service }
    status { :scheduled }
    notes { nil }
    auto_generated { false }
    association :service_event_type, factory: :service_event_type_service
    transient do
      route { nil }
      route_date { nil }
      route_sequence { nil }
    end
    after(:build) do |event, evaluator|
      event.user ||= event.order&.created_by || create(:user)
      if evaluator.route_date.present?
        event.scheduled_on = evaluator.route_date.to_date
      elsif evaluator.route.present? && event.scheduled_on.blank?
        event.scheduled_on = evaluator.route.route_date
      end
    end
    after(:create) do |event, evaluator|
      next unless evaluator.route

      target_route = evaluator.route
      stop = RouteStop.find_or_initialize_by(service_event: event)
      position =
        if evaluator.route_sequence.present?
          evaluator.route_sequence.to_i
        elsif stop.persisted? && stop.route_id == target_route.id && stop.position.present?
          stop.position
        else
          target_route.route_stops.where.not(id: stop.id).maximum(:position).to_i + 1
        end

      stop.route = target_route
      stop.position = position
      stop.status = event.status
      stop.save!

      if evaluator.route_date.present?
        target_date = evaluator.route_date.to_date
        event.update_column(:scheduled_on, target_date) if event.scheduled_on != target_date
      end
      target_route.truck&.recalculate_waste_load!
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
