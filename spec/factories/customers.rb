FactoryBot.define do
  factory :customer do
    first_name   { "John" }
    last_name    { "Doe" }
    company_name { nil }
    billing_email { "john.doe@example.com" }
    phone        { "555-555-5555" }
  end
end
