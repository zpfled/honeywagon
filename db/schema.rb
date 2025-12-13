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

ActiveRecord::Schema[8.1].define(version: 2025_12_13_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "customers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "billing_email"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["company_name"], name: "index_customers_on_company_name"
    t.index ["last_name"], name: "index_customers_on_last_name"
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

  create_table "order_line_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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
    t.index ["order_id"], name: "index_order_line_items_on_order_id"
    t.index ["rate_plan_id"], name: "index_order_line_items_on_rate_plan_id"
    t.index ["unit_type_id"], name: "index_order_line_items_on_unit_type_id"
  end

  create_table "order_units", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "daily_rate_cents"
    t.uuid "order_id", null: false
    t.date "placed_on"
    t.date "removed_on"
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_units_on_order_id"
    t.index ["unit_id"], name: "index_order_units_on_unit_id"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
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
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["location_id"], name: "index_orders_on_location_id"
  end

  create_table "rate_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active"
    t.string "billing_period"
    t.datetime "created_at", null: false
    t.date "effective_on"
    t.date "expires_on"
    t.integer "price_cents"
    t.string "service_schedule"
    t.uuid "unit_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_type_id"], name: "index_rate_plans_on_unit_type_id"
  end

  create_table "service_event_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.uuid "service_event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_event_id"], name: "index_service_event_reports_on_service_event_id", unique: true
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
    t.datetime "created_at", null: false
    t.integer "event_type"
    t.text "notes"
    t.uuid "order_id", null: false
    t.date "scheduled_on"
    t.uuid "service_event_type_id", null: false
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["auto_generated"], name: "index_service_events_on_auto_generated"
    t.index ["order_id"], name: "index_service_events_on_order_id"
    t.index ["service_event_type_id"], name: "index_service_events_on_service_event_type_id"
  end

  create_table "unit_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "next_serial", default: 1, null: false
    t.string "prefix"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "units", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "manufacturer", null: false
    t.string "serial"
    t.string "status"
    t.uuid "unit_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["serial"], name: "index_units_on_serial", unique: true
    t.index ["status"], name: "index_units_on_status"
    t.index ["unit_type_id"], name: "index_units_on_unit_type_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "driver", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "locations", "customers"
  add_foreign_key "order_line_items", "orders"
  add_foreign_key "order_line_items", "rate_plans"
  add_foreign_key "order_line_items", "unit_types"
  add_foreign_key "order_units", "orders"
  add_foreign_key "order_units", "units"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "locations"
  add_foreign_key "rate_plans", "unit_types"
  add_foreign_key "service_event_reports", "service_events"
  add_foreign_key "service_events", "orders"
  add_foreign_key "service_events", "service_event_types"
  add_foreign_key "units", "unit_types"
end
