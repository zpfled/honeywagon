json.extract! rate_plan, :id, :unit_type_id, :service_schedule, :billing_period, :price_cents, :active, :effective_on, :expires_on, :created_at, :updated_at
json.url rate_plan_url(rate_plan, format: :json)
