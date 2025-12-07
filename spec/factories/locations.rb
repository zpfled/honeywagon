FactoryBot.define do
  factory :location do
    association :customer
    label { "Job Site" }
    street { "123 Main St" }
    city   { "La Farge" }
    state  { "WI" }
    zip    { "54639" }
    lat    { 43.574 }
    lng    { -90.638 }
    access_notes { "Gate code 1234" }
    dump_site { false }

    trait :dump_site do
      dump_site { true }
      customer  { nil }
      label { "WWTP" }
    end
  end
end
