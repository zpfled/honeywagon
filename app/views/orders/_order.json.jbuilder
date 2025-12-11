json.extract! order, :id, :customer_id, :location_id, :external_reference, :status, :start_date, :end_date, :rental_subtotal_cents, :delivery_fee_cents, :pickup_fee_cents, :discount_cents, :tax_cents, :total_cents, :notes, :created_at, :updated_at
json.url order_url(order, format: :json)
