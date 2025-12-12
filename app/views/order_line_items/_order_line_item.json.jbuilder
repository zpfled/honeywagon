json.extract! order_line_item, :id, :order_id, :unit_type_id, :rate_plan_id, :service_schedule, :billing_period, :quantity, :unit_price_cents, :subtotal_cents, :created_at, :updated_at
json.url order_line_item_url(order_line_item, format: :json)
