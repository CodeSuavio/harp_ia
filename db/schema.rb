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

ActiveRecord::Schema[8.1].define(version: 2026_10_11_120001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bill_authors", force: :cascade do |t|
    t.bigint "bill_id", null: false
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["bill_id", "deputy_id"], name: "index_bill_authors_on_bill_id_and_deputy_id", unique: true
    t.index ["bill_id"], name: "index_bill_authors_on_bill_id"
    t.index ["deputy_id"], name: "index_bill_authors_on_deputy_id"
  end

  create_table "bill_themes", force: :cascade do |t|
    t.bigint "bill_id", null: false
    t.bigint "theme_id", null: false
    t.index ["bill_id", "theme_id"], name: "index_bill_themes_on_bill_id_and_theme_id", unique: true
    t.index ["bill_id"], name: "index_bill_themes_on_bill_id"
    t.index ["theme_id"], name: "index_bill_themes_on_theme_id"
  end

  create_table "bills", force: :cascade do |t|
    t.string "bill_number"
    t.string "bill_type"
    t.datetime "created_at", null: false
    t.bigint "deputy_id"
    t.string "keywords"
    t.integer "number"
    t.bigint "party_id"
    t.datetime "submission_date"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "year"
    t.index ["bill_type", "number", "year"], name: "index_bills_on_bill_type_and_number_and_year", unique: true
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
    t.string "title"
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
    t.bigint "json_id"
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
    t.index ["electoral_status"], name: "index_deputies_on_electoral_status"
    t.index ["json_id"], name: "index_deputies_on_json_id", unique: true
    t.index ["party_id"], name: "index_deputies_on_party_id"
    t.index ["state_label"], name: "index_deputies_on_state_label"
  end

  create_table "expenses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.decimal "document_amount"
    t.datetime "document_date"
    t.string "document_url"
    t.string "expense_type"
    t.integer "month"
    t.decimal "net_amount"
    t.string "supplier"
    t.string "supplier_cnpj_cpf"
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["deputy_id", "year", "month"], name: "index_expenses_on_deputy_id_and_year_and_month"
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

  create_table "models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_models_on_family"
    t.index ["modalities"], name: "index_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "parties", force: :cascade do |t|
    t.boolean "active"
    t.integer "camara_id"
    t.datetime "created_at", null: false
    t.string "former_labels"
    t.string "label"
    t.bigint "leader_json_id"
    t.string "leader_name"
    t.string "logo_url"
    t.string "name"
    t.integer "number"
    t.date "registered_on"
    t.integer "seats_at_start"
    t.string "succeeded_by"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "party_affiliations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.string "kind", null: false
    t.integer "legislature", null: false
    t.bigint "party_id"
    t.string "party_label", null: false
    t.date "started_on", null: false
    t.datetime "updated_at", null: false
    t.index ["deputy_id", "started_on"], name: "index_party_affiliations_on_deputy_id_and_started_on"
    t.index ["deputy_id"], name: "index_party_affiliations_on_deputy_id"
    t.index ["party_id"], name: "index_party_affiliations_on_party_id"
  end

  create_table "poll_bills", force: :cascade do |t|
    t.bigint "bill_id", null: false
    t.datetime "created_at", null: false
    t.bigint "poll_id", null: false
    t.datetime "updated_at", null: false
    t.index ["bill_id"], name: "index_poll_bills_on_bill_id"
    t.index ["poll_id", "bill_id"], name: "index_poll_bills_on_poll_id_and_bill_id", unique: true
    t.index ["poll_id"], name: "index_poll_bills_on_poll_id"
  end

  create_table "poll_orientations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.string "orientation", null: false
    t.bigint "party_id"
    t.bigint "poll_id", null: false
    t.datetime "updated_at", null: false
    t.index ["party_id"], name: "index_poll_orientations_on_party_id"
    t.index ["poll_id", "label"], name: "index_poll_orientations_on_poll_id_and_label", unique: true
    t.index ["poll_id"], name: "index_poll_orientations_on_poll_id"
  end

  create_table "poll_themes", force: :cascade do |t|
    t.bigint "poll_id", null: false
    t.bigint "theme_id", null: false
    t.index ["poll_id", "theme_id"], name: "index_poll_themes_on_poll_id_and_theme_id", unique: true
    t.index ["poll_id"], name: "index_poll_themes_on_poll_id"
    t.index ["theme_id"], name: "index_poll_themes_on_theme_id"
  end

  create_table "polls", force: :cascade do |t|
    t.boolean "approval"
    t.bigint "bill_id"
    t.datetime "created_at", null: false
    t.datetime "date"
    t.text "description"
    t.string "json_id"
    t.string "label_comission"
    t.datetime "updated_at", null: false
    t.index ["bill_id"], name: "index_polls_on_bill_id"
    t.index ["json_id"], name: "index_polls_on_json_id", unique: true
  end

  create_table "proposal_polls", force: :cascade do |t|
    t.string "favorable_vote", null: false
    t.bigint "poll_id", null: false
    t.bigint "proposal_id", null: false
    t.index ["poll_id"], name: "index_proposal_polls_on_poll_id"
    t.index ["proposal_id", "poll_id"], name: "index_proposal_polls_on_proposal_id_and_poll_id", unique: true
    t.index ["proposal_id"], name: "index_proposal_polls_on_proposal_id"
  end

  create_table "proposals", force: :cascade do |t|
    t.string "author"
    t.datetime "created_at", null: false
    t.bigint "deputy_id"
    t.text "excerpt"
    t.bigint "party_id"
    t.string "source_kind", null: false
    t.string "source_url"
    t.string "state_label"
    t.bigint "theme_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["deputy_id"], name: "index_proposals_on_deputy_id"
    t.index ["party_id"], name: "index_proposals_on_party_id"
    t.index ["theme_id"], name: "index_proposals_on_theme_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "themes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "keywords"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_themes_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deputy_id", null: false
    t.bigint "poll_id", null: false
    t.datetime "updated_at", null: false
    t.string "vote"
    t.index ["deputy_id"], name: "index_votes_on_deputy_id"
    t.index ["poll_id", "deputy_id"], name: "index_votes_on_poll_id_and_deputy_id", unique: true
    t.index ["poll_id"], name: "index_votes_on_poll_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bill_authors", "bills"
  add_foreign_key "bill_authors", "deputies"
  add_foreign_key "bill_themes", "bills"
  add_foreign_key "bill_themes", "themes"
  add_foreign_key "bills", "deputies"
  add_foreign_key "bills", "parties"
  add_foreign_key "candidates", "deputies", column: "current_deputy_id", primary_key: "json_id"
  add_foreign_key "candidates", "parties"
  add_foreign_key "chats", "users"
  add_foreign_key "deputies", "parties"
  add_foreign_key "expenses", "deputies"
  add_foreign_key "messages", "chats"
  add_foreign_key "party_affiliations", "deputies"
  add_foreign_key "party_affiliations", "parties"
  add_foreign_key "poll_bills", "bills"
  add_foreign_key "poll_bills", "polls"
  add_foreign_key "poll_orientations", "parties"
  add_foreign_key "poll_orientations", "polls"
  add_foreign_key "poll_themes", "polls"
  add_foreign_key "poll_themes", "themes"
  add_foreign_key "polls", "bills"
  add_foreign_key "proposal_polls", "polls"
  add_foreign_key "proposal_polls", "proposals"
  add_foreign_key "proposals", "deputies"
  add_foreign_key "proposals", "parties"
  add_foreign_key "proposals", "themes"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "votes", "deputies"
  add_foreign_key "votes", "polls"
end
