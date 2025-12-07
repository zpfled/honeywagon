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

ActiveRecord::Schema[8.1].define(version: 2025_12_07_010004) do
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

  create_table "unit_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "units", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "serial"
    t.string "status"
    t.uuid "unit_type_id", null: false
    t.datetime "updated_at", null: false
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
  add_foreign_key "units", "unit_types"
end
