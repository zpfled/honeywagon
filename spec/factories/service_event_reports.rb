FactoryBot.define do
  factory :service_event_report do
    association :service_event, factory: :service_event
    data do
      {
        "estimated_gallons_pumped" => "100",
        "units_pumped" => "2"
      }
    end
  end
end
