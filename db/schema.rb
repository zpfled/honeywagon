# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_05_205109) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "fuel_price_per_gal_cents", default: 0, null: false
    t.uuid "home_base_id"
    t.string "name", null: false
    t.boolean "setup_completed", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["home_base_id"], name: "index_companies_on_home_base_id"
  end

  create_table "customers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "billing_email"
    t.string "business_name"
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["business_name"], name: "index_customers_on_business_name"
    t.index ["company_id"], name: "index_customers_on_company_id"
    t.index ["display_name"], name: "index_customers_on_display_name"
    t.index ["last_name"], name: "index_customers_on_last_name"
  end

  create_table "dump_sites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "location_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_dump_sites_on_company_id"
    t.index ["location_id"], name: "index_dump_sites_on_location_id"
  end

  create_table "expenses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "applies_to", default: [], array: true
    t.decimal "base_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.string "category", null: false
    t.uuid "company_id", null: false
    t.string "cost_type", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.decimal "package_size", precision: 12, scale: 3
    t.date "season_end"
    t.date "season_start"
    t.string "unit_label"
    t.datetime "updated_at", null: false
    t.index ["applies_to"], name: "index_expenses_on_applies_to", using: :gin
    t.index ["company_id", "category"], name: "index_expenses_on_company_id_and_category"
    t.index ["company_id"], name: "index_expenses_on_company_id"
  end

  create_table "locations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_notes"
    t.string "city"
    t.datetime "created_at", null: false
    t.uuid "customer_id"
    t.boolean "dump_site"
    t.string "label"
    t.decimal "lat"
    t.decimal "lng"
    t.string "state"
    t.string "street"
    t.datetime "updated_at", null: false
    t.string "zip"
    t.index ["customer_id"], name: "index_locations_on_customer_id"
    t.index ["dump_site"], name: "index_locations_on_dump_site"
  end

  create_table "order_units", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "billing_period", null: false
    t.datetime "created_at", null: false
    t.integer "daily_rate_cents"
    t.uuid "order_id", null: false
    t.date "placed_on"
    t.date "removed_on"
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["billing_period"], name: "index_order_units_on_billing_period"
    t.index ["order_id"], name: "index_order_units_on_order_id"
    t.index ["unit_id"], name: "index_order_units_on_unit_id"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.uuid "customer_id", null: false
    t.integer "delivery_fee_cents"
    t.integer "discount_cents"
    t.date "end_date"
    t.string "external_reference"
    t.uuid "location_id", null: false
    t.text "notes"
    t.integer "pickup_fee_cents"
    t.integer "rental_subtotal_cents"
    t.date "start_date"
    t.string "status"
    t.integer "tax_cents"
    t.integer "total_cents"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_orders_on_company_id"
    t.index ["created_by_id"], name: "index_orders_on_created_by_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["location_id"], name: "index_orders_on_location_id"
  end

  create_table "rate_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active"
    t.string "billing_period"
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.date "effective_on"
    t.date "expires_on"
    t.integer "price_cents"
    t.string "service_schedule"
    t.uuid "unit_type_id"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_rate_plans_on_company_id"
    t.index ["unit_type_id"], name: "index_rate_plans_on_unit_type_id"
  end

  create_table "rental_line_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "billing_period"
    t.datetime "created_at", null: false
    t.uuid "order_id", null: false
    t.integer "quantity", default: 0, null: false
    t.uuid "rate_plan_id", null: false
    t.string "service_schedule"
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "unit_price_cents", default: 0, null: false
    t.uuid "unit_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_rental_line_items_on_order_id"
    t.index ["rate_plan_id"], name: "index_rental_line_items_on_rate_plan_id"
    t.index ["unit_type_id"], name: "index_rental_line_items_on_unit_type_id"
  end

  create_table "routes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "estimated_drive_meters"
    t.integer "estimated_drive_seconds"
    t.boolean "optimization_stale", default: true, null: false
    t.date "route_date", null: false
    t.uuid "trailer_id"
    t.uuid "truck_id"
    t.datetime "updated_at", null: false
    t.index ["company_id", "route_date"], name: "index_routes_on_company_id_and_route_date"
    t.index ["trailer_id"], name: "index_routes_on_trailer_id"
    t.index ["truck_id"], name: "index_routes_on_truck_id"
  end

  create_table "service_event_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.uuid "service_event_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["service_event_id"], name: "index_service_event_reports_on_service_event_id", unique: true
    t.index ["user_id"], name: "index_service_event_reports_on_user_id"
  end

  create_table "service_event_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.jsonb "report_fields", default: [], null: false
    t.boolean "requires_report", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_service_event_types_on_key", unique: true
  end

  create_table "service_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "auto_generated", default: false, null: false
    t.date "completed_on"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.uuid "deleted_by_id"
    t.integer "drive_distance_meters", default: 0, null: false
    t.integer "drive_duration_seconds", default: 0, null: false
    t.uuid "dump_site_id"
    t.integer "estimated_cost_cents", default: 0, null: false
    t.integer "estimated_gallons_override"
    t.integer "event_type"
    t.text "notes"
    t.uuid "order_id"
    t.date "route_date"
    t.uuid "route_id"
    t.integer "route_sequence"
    t.date "scheduled_on"
    t.uuid "service_event_type_id", null: false
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["auto_generated"], name: "index_service_events_on_auto_generated"
    t.index ["deleted_at"], name: "index_service_events_on_deleted_at"
    t.index ["deleted_by_id"], name: "index_service_events_on_deleted_by_id"
    t.index ["dump_site_id"], name: "index_service_events_on_dump_site_id"
    t.index ["order_id"], name: "index_service_events_on_order_id"
    t.index ["route_id", "route_sequence"], name: "index_service_events_on_route_id_and_route_sequence"
    t.index ["route_id"], name: "index_service_events_on_route_id"
    t.index ["service_event_type_id"], name: "index_service_events_on_service_event_type_id"
    t.index ["user_id"], name: "index_service_events_on_user_id"
  end

  create_table "service_line_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.uuid "order_id", null: false
    t.uuid "rate_plan_id"
    t.string "service_schedule", default: "none", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "unit_price_cents", default: 0, null: false
    t.integer "units_serviced", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_service_line_items_on_order_id"
    t.index ["rate_plan_id"], name: "index_service_line_items_on_rate_plan_id"
  end

  create_table "trailers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "capacity_spots", default: 0, null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "identifier", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "identifier"], name: "index_trailers_on_company_id_and_identifier", unique: true
    t.index ["company_id"], name: "index_trailers_on_company_id"
  end

  create_table "trucks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "clean_water_capacity_gal", default: 0, null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.decimal "miles_per_gallon", precision: 6, scale: 2
    t.string "name", null: false
    t.string "number", null: false
    t.datetime "updated_at", null: false
    t.integer "waste_capacity_gal", default: 0, null: false
    t.integer "waste_load_gal", default: 0, null: false
    t.index ["company_id", "number"], name: "index_trucks_on_company_id_and_number", unique: true
    t.index ["company_id"], name: "index_trucks_on_company_id"
  end

  create_table "unit_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "delivery_clean_gallons", default: 0, null: false
    t.string "name"
    t.integer "next_serial", default: 1, null: false
    t.integer "pickup_clean_gallons", default: 0, null: false
    t.integer "pickup_waste_gallons", default: 0, null: false
    t.string "prefix"
    t.integer "service_clean_gallons", default: 0, null: false
    t.integer "service_waste_gallons", default: 0, null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_unit_types_on_company_id"
  end

  create_table "units", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "manufacturer"
    t.string "serial"
    t.string "status"
    t.uuid "unit_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_units_on_company_id"
    t.index ["serial"], name: "index_units_on_serial", unique: true
    t.index ["status"], name: "index_units_on_status"
    t.index ["unit_type_id"], name: "index_units_on_unit_type_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "driver", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "weather_forecasts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.date "forecast_date", null: false
    t.integer "high_temp"
    t.string "icon_url"
    t.decimal "latitude", precision: 8, scale: 4
    t.decimal "longitude", precision: 9, scale: 4
    t.integer "low_temp"
    t.integer "precip_percent"
    t.datetime "retrieved_at", null: false
    t.string "summary"
    t.datetime "updated_at", null: false
    t.index ["company_id", "forecast_date", "latitude", "longitude"], name: "index_weather_forecasts_on_company_date_and_location", unique: true
    t.index ["company_id"], name: "index_weather_forecasts_on_company_id"
  end

  add_foreign_key "companies", "locations", column: "home_base_id"
  add_foreign_key "customers", "companies"
  add_foreign_key "dump_sites", "companies"
  add_foreign_key "dump_sites", "locations"
  add_foreign_key "expenses", "companies"
  add_foreign_key "locations", "customers"
  add_foreign_key "order_units", "orders"
  add_foreign_key "order_units", "units"
  add_foreign_key "orders", "companies"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "locations"
  add_foreign_key "orders", "users", column: "created_by_id"
  add_foreign_key "rate_plans", "companies"
  add_foreign_key "rate_plans", "unit_types"
  add_foreign_key "rental_line_items", "orders"
  add_foreign_key "rental_line_items", "rate_plans"
  add_foreign_key "rental_line_items", "unit_types"
  add_foreign_key "routes", "companies"
  add_foreign_key "routes", "trailers"
  add_foreign_key "routes", "trucks"
  add_foreign_key "service_event_reports", "service_events"
  add_foreign_key "service_event_reports", "users"
  add_foreign_key "service_events", "dump_sites"
  add_foreign_key "service_events", "orders"
  add_foreign_key "service_events", "routes"
  add_foreign_key "service_events", "service_event_types"
  add_foreign_key "service_events", "users"
  add_foreign_key "service_events", "users", column: "deleted_by_id"
  add_foreign_key "service_line_items", "orders"
  add_foreign_key "service_line_items", "rate_plans"
  add_foreign_key "trailers", "companies"
  add_foreign_key "trucks", "companies"
  add_foreign_key "unit_types", "companies"
  add_foreign_key "units", "companies"
  add_foreign_key "units", "unit_types"
  add_foreign_key "users", "companies"
  add_foreign_key "weather_forecasts", "companies"
end
