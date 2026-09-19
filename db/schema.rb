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

ActiveRecord::Schema[8.1].define(version: 2026_09_19_174758) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.bigint "party_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deputy_id"], name: "index_bills_on_deputy_id"
    t.index ["party_id"], name: "index_bills_on_party_id"
  end

  create_table "candidates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_deputy_id"
    t.bigint "party_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_deputy_id"], name: "index_candidates_on_current_deputy_id"
    t.index ["party_id"], name: "index_candidates_on_party_id"
  end

  create_table "deputies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "party_id", null: false
    t.datetime "updated_at", null: false
    t.index ["party_id"], name: "index_deputies_on_party_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deputy_id"], name: "index_expenses_on_deputy_id"
  end

  create_table "parties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "polls", force: :cascade do |t|
    t.bigint "bill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bill_id"], name: "index_polls_on_bill_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "bill_id", null: false
    t.bigint "candidate_id", null: false
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.bigint "party_id", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["bill_id"], name: "index_users_on_bill_id"
    t.index ["candidate_id"], name: "index_users_on_candidate_id"
    t.index ["deputy_id"], name: "index_users_on_deputy_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["party_id"], name: "index_users_on_party_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.bigint "poll_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deputy_id"], name: "index_votes_on_deputy_id"
    t.index ["poll_id"], name: "index_votes_on_poll_id"
  end

  add_foreign_key "bills", "deputies"
  add_foreign_key "bills", "parties"
  add_foreign_key "candidates", "deputies", column: "current_deputy_id"
  add_foreign_key "candidates", "parties"
  add_foreign_key "deputies", "parties"
  add_foreign_key "expenses", "deputies"
  add_foreign_key "polls", "bills"
  add_foreign_key "users", "bills"
  add_foreign_key "users", "candidates"
  add_foreign_key "users", "deputies"
  add_foreign_key "users", "parties"
  add_foreign_key "votes", "deputies"
  add_foreign_key "votes", "polls"
end
