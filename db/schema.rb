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

ActiveRecord::Schema[8.1].define(version: 2026_03_06_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_snapshots", force: :cascade do |t|
    t.integer "confidence_level", null: false
    t.datetime "created_at", null: false
    t.integer "price_p25_cents"
    t.integer "price_p50_cents"
    t.integer "price_p75_cents"
    t.integer "route_median_duration_minutes"
    t.integer "sample_count"
    t.bigint "search_run_id", null: false
    t.datetime "updated_at", null: false
    t.integer "volatility"
    t.index ["search_run_id"], name: "index_analysis_snapshots_on_search_run_id", unique: true
  end

  create_table "flight_samples", force: :cascade do |t|
    t.integer "air_time_minutes"
    t.jsonb "airlines"
    t.datetime "created_at", null: false
    t.string "currency"
    t.datetime "departure_datetime"
    t.integer "layover_time_minutes"
    t.boolean "luggage_included", null: false
    t.integer "price_cents"
    t.string "provider"
    t.datetime "return_datetime"
    t.bigint "search_run_id", null: false
    t.integer "stops"
    t.datetime "updated_at", null: false
    t.index ["price_cents"], name: "index_flight_samples_on_price_cents"
    t.index ["search_run_id"], name: "index_flight_samples_on_search_run_id"
  end

  create_table "search_intents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "destination_airport", null: false
    t.date "earliest_departure", null: false
    t.date "latest_return", null: false
    t.integer "luggage_requirement"
    t.integer "max_stay_days", null: false
    t.integer "max_stops"
    t.integer "min_stay_days", null: false
    t.string "origin_airport", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_search_intents_on_user_id"
  end

  create_table "search_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "data_fresh_until"
    t.text "error_message"
    t.datetime "finished_at"
    t.bigint "search_intent_id", null: false
    t.datetime "started_at"
    t.integer "state", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["search_intent_id"], name: "index_search_runs_on_search_intent_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "analysis_snapshots", "search_runs"
  add_foreign_key "flight_samples", "search_runs"
  add_foreign_key "search_intents", "users"
  add_foreign_key "search_runs", "search_intents"
end
