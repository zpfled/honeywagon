FactoryBot.define do
  factory :service_line_item do
    association :order
    description { "Customer-owned units" }
    service_schedule { RatePlan::SERVICE_SCHEDULES[:weekly] }
    units_serviced { 5 }
  end
end
