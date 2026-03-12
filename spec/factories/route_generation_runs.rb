FactoryBot.define do
  factory :route_generation_run do
    company
    created_by { association(:user, company: company) }
    scope_key { "calendar:v1:#{SecureRandom.uuid}:#{Date.current.iso8601}:#{(Date.current + 27.days).iso8601}" }
    window_start { Date.current }
    window_end { Date.current + 27.days }
    strategy { 'capacity_v1' }
    state { :active }
    source_params { {} }
    metadata { {} }
  end
end
