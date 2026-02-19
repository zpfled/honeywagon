FactoryBot.define do
  factory :order_series do
    company
    created_by { association(:user, company: company) }
    name { "Weekend Series" }
  end
end
