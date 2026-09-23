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

ActiveRecord::Schema[8.1].define(version: 2026_09_22_233436) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bills", force: :cascade do |t|
    t.string "bill_number"
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.string "keywords"
    t.bigint "party_id", null: false
    t.date "submission_date"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "year"
    t.index ["deputy_id"], name: "index_bills_on_deputy_id"
    t.index ["party_id"], name: "index_bills_on_party_id"
  end

  create_table "candidates", force: :cascade do |t|
    t.string "ballot_name"
    t.string "candidacy_status"
    t.datetime "created_at", null: false
    t.bigint "current_deputy_id"
    t.string "education_level"
    t.string "electoral_id"
    t.string "gender"
    t.string "name"
    t.integer "number"
    t.string "occupation"
    t.bigint "party_id", null: false
    t.string "photo_file"
    t.string "race_color"
    t.boolean "running_for_reelection"
    t.string "state_label"
    t.datetime "updated_at", null: false
    t.index ["current_deputy_id"], name: "index_candidates_on_current_deputy_id"
    t.index ["party_id"], name: "index_candidates_on_party_id"
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "deputies", force: :cascade do |t|
    t.string "city_of_birth"
    t.string "cpf"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "education_level"
    t.string "electoral_status"
    t.string "email"
    t.string "name"
    t.string "office_building"
    t.string "office_phone"
    t.string "office_room"
    t.bigint "party_id", null: false
    t.string "photo_url"
    t.string "social_media"
    t.string "state_label"
    t.string "state_of_birth"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["party_id"], name: "index_deputies_on_party_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.decimal "document_amount"
    t.date "document_date"
    t.string "document_url"
    t.string "expense_type"
    t.integer "month"
    t.decimal "net_amount"
    t.string "supplier"
    t.string "supplier_cnpj_cpf"
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["deputy_id"], name: "index_expenses_on_deputy_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "parties", force: :cascade do |t|
    t.boolean "active"
    t.integer "camara_id"
    t.datetime "created_at", null: false
    t.string "former_labels"
    t.string "label"
    t.string "name"
    t.integer "number"
    t.date "registered_on"
    t.string "succeeded_by"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "polls", force: :cascade do |t|
    t.string "approval"
    t.bigint "bill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "date"
    t.text "description"
    t.string "label_comission"
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
    t.string "first_name"
    t.string "last_name"
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
    t.string "vote"
    t.index ["deputy_id"], name: "index_votes_on_deputy_id"
    t.index ["poll_id"], name: "index_votes_on_poll_id"
  end

  add_foreign_key "bills", "deputies"
  add_foreign_key "bills", "parties"
  add_foreign_key "candidates", "deputies", column: "current_deputy_id"
  add_foreign_key "candidates", "parties"
  add_foreign_key "chats", "users"
  add_foreign_key "deputies", "parties"
  add_foreign_key "expenses", "deputies"
  add_foreign_key "messages", "chats"
  add_foreign_key "polls", "bills"
  add_foreign_key "users", "bills"
  add_foreign_key "users", "candidates"
  add_foreign_key "users", "deputies"
  add_foreign_key "users", "parties"
  add_foreign_key "votes", "deputies"
  add_foreign_key "votes", "polls"
end
