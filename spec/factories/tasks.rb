FactoryBot.define do
  factory :task do
    company
    title { "Follow up with client" }
    due_on { Date.current }
    status { "todo" }
  end
end
