FactoryBot.define do
  factory :service_event_report do
    association :service_event, factory: :service_event
    after(:build) do |report|
      report.user ||= report.service_event&.user || create(:user)
    end
    data do
      {
        "estimated_gallons_pumped" => "100",
        "units_pumped" => "2"
      }
    end
  end
end
