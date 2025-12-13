FactoryBot.define do
  factory :service_event_type do
    sequence(:key) { |n| "custom_type_#{n}" }
    sequence(:name) { |n| "Custom Type #{n}" }
    requires_report { false }
    report_fields { [] }

    factory :service_event_type_delivery do
      key { "delivery" }
      name { "Delivery" }
      requires_report { false }

      initialize_with do
        ServiceEventType.find_or_create_by!(key: key) do |type|
          type.name = name
          type.requires_report = requires_report
          type.report_fields = report_fields
        end
      end
    end

    factory :service_event_type_service do
      key { "service" }
      name { "Service" }
      requires_report { true }
      report_fields do
        [
          { "key" => "customer_name", "label" => "Customer Name" }
        ]
      end

      initialize_with do
        ServiceEventType.find_or_create_by!(key: key) do |type|
          type.name = name
          type.requires_report = requires_report
          type.report_fields = report_fields
        end
      end
    end

    factory :service_event_type_pickup do
      key { "pickup" }
      name { "Pickup" }
      requires_report { true }
      report_fields do
        [
          { "key" => "customer_name", "label" => "Customer Name" }
        ]
      end

      initialize_with do
        ServiceEventType.find_or_create_by!(key: key) do |type|
          type.name = name
          type.requires_report = requires_report
          type.report_fields = report_fields
        end
      end
    end
  end
end
