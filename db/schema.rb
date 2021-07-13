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

ActiveRecord::Schema.define(version: 2021_07_06_181815) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "legacy_record_id"
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.uuid "record_id"
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bitflyer_connections", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id", null: false
    t.string "encrypted_access_token"
    t.string "encrypted_access_token_iv"
    t.string "encrypted_refresh_token"
    t.string "encrypted_refresh_token_iv"
    t.string "expires_in"
    t.datetime "access_expiration_time"
    t.string "display_name"
    t.string "state_token"
    t.string "scope"
    t.string "status"
    t.string "country"
    t.boolean "is_verified"
    t.string "recipient_id"
    t.string "default_currency"
    t.datetime "created_at", precision: 6, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: 6, default: -> { "now()" }, null: false
    t.boolean "access_token_rekeyed", default: false
    t.boolean "refresh_token_rekeyed", default: false
    t.index ["encrypted_access_token_iv"], name: "index_bitflyer_connections_on_encrypted_access_token_iv", unique: true
    t.index ["encrypted_refresh_token_iv"], name: "index_bitflyer_connections_on_encrypted_refresh_token_iv", unique: true
    t.index ["is_verified"], name: "index_bitflyer_connections_on_is_verified"
    t.index ["publisher_id"], name: "index_bitflyer_connections_on_publisher_id"
    t.index ["recipient_id"], name: "index_bitflyer_connections_on_recipient_id", unique: true
    t.index ["status"], name: "index_bitflyer_connections_on_status"
  end

  create_table "cached_uphold_tips", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "uphold_transaction_id"
    t.string "amount"
    t.string "settlement_currency"
    t.string "settlement_amount"
    t.datetime "uphold_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "uphold_connection_for_channel_id"
    t.index ["uphold_transaction_id"], name: "index_cached_uphold_tips_on_uphold_transaction_id", unique: true
  end

  create_table "case_notes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "case_id", null: false
    t.uuid "created_by_id"
    t.boolean "public", default: true, null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_case_notes_on_case_id"
    t.index ["created_by_id"], name: "index_case_notes_on_created_by_id"
  end

  create_table "case_replies", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cases", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "solicit_question"
    t.text "accident_question"
    t.string "status", default: "new"
    t.uuid "publisher_id"
    t.uuid "assignee_id"
    t.datetime "open_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.serial "case_number", null: false
    t.index ["assignee_id"], name: "index_cases_on_assignee_id"
    t.index ["publisher_id"], name: "index_cases_on_publisher_id", unique: true
    t.index ["status"], name: "index_cases_on_status"
  end

  create_table "channel_transfers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "transfer_from_id"
    t.uuid "transfer_to_id"
    t.uuid "channel_id"
    t.boolean "suspended"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "transfer_to_channel_id"
    t.index ["channel_id"], name: "index_channel_transfers_on_channel_id"
    t.index ["transfer_from_id"], name: "index_channel_transfers_on_transfer_from_id"
    t.index ["transfer_to_channel_id"], name: "index_channel_transfers_on_transfer_to_channel_id"
    t.index ["transfer_to_id"], name: "index_channel_transfers_on_transfer_to_id"
  end

  create_table "channels", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id"
    t.boolean "created_via_api", default: false, null: false
    t.boolean "verified", default: false
    t.string "details_type"
    t.uuid "details_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "verification_status"
    t.string "verification_details"
    t.datetime "verified_at"
    t.boolean "verification_pending", default: false, null: false
    t.uuid "contested_by_channel_id"
    t.string "contest_token"
    t.datetime "contest_timesout_at"
    t.string "deposit_id"
    t.index ["contested_by_channel_id"], name: "index_channels_on_contested_by_channel_id"
    t.index ["details_type", "details_id"], name: "index_channels_on_details_type_and_details_id", unique: true
    t.index ["publisher_id"], name: "index_channels_on_publisher_id"
  end

  create_table "csp_violation_reports", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.jsonb "report"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["report"], name: "index_csp_violation_reports_on_report", unique: true
  end

  create_table "daily_metrics", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.jsonb "result"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["result"], name: "index_daily_metrics_on_result"
  end

  create_table "faq_categories", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.integer "rank"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_faq_categories_on_name", unique: true
    t.index ["rank"], name: "index_faq_categories_on_rank"
  end

  create_table "faqs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "question"
    t.string "answer"
    t.integer "rank"
    t.uuid "faq_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published", default: false
    t.index ["faq_category_id"], name: "index_faqs_on_faq_category_id"
    t.index ["question"], name: "index_faqs_on_question", unique: true
    t.index ["rank"], name: "index_faqs_on_rank"
  end

  create_table "gemini_connections", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id", null: false
    t.string "encrypted_access_token"
    t.string "encrypted_access_token_iv"
    t.string "encrypted_refresh_token"
    t.string "encrypted_refresh_token_iv"
    t.string "expires_in"
    t.datetime "access_expiration_time"
    t.string "display_name"
    t.string "state_token"
    t.string "scope"
    t.string "status"
    t.string "country"
    t.boolean "is_verified"
    t.string "recipient_id"
    t.datetime "created_at", precision: 6, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: 6, default: -> { "now()" }, null: false
    t.string "default_currency"
    t.boolean "access_token_rekeyed", default: false
    t.boolean "refresh_token_rekeyed", default: false
    t.index ["encrypted_access_token_iv"], name: "index_gemini_connections_on_encrypted_access_token_iv", unique: true
    t.index ["encrypted_refresh_token_iv"], name: "index_gemini_connections_on_encrypted_refresh_token_iv", unique: true
    t.index ["is_verified"], name: "index_gemini_connections_on_is_verified"
    t.index ["publisher_id"], name: "index_gemini_connections_on_publisher_id"
    t.index ["status"], name: "index_gemini_connections_on_status"
  end

  create_table "github_channel_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "github_channel_id"
    t.string "auth_provider"
    t.string "name"
    t.string "channel_url"
    t.string "nickname"
    t.string "thumbnail_url"
    t.jsonb "stats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_channel_id"], name: "index_github_channel_details_on_github_channel_id"
  end

  create_table "invoice_files", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "invoice_id"
    t.uuid "uploaded_by_id"
    t.boolean "archived", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_files_on_invoice_id"
    t.index ["uploaded_by_id"], name: "index_invoice_files_on_uploaded_by_id"
  end

  create_table "invoices", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id"
    t.date "date"
    t.string "amount", default: "0"
    t.string "finalized_amount"
    t.uuid "paid_by_id"
    t.date "payment_date"
    t.uuid "finalized_by_id"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["finalized_by_id"], name: "index_invoices_on_finalized_by_id"
    t.index ["paid_by_id"], name: "index_invoices_on_paid_by_id"
    t.index ["publisher_id"], name: "index_invoices_on_publisher_id"
  end

  create_table "legacy_publishers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "brave_publisher_id"
    t.string "name"
    t.string "email"
    t.string "verification_token"
    t.boolean "verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "phone"
    t.string "phone_normalized"
    t.string "encrypted_authentication_token"
    t.string "encrypted_authentication_token_iv"
    t.string "verification_method"
    t.datetime "authentication_token_expires_at"
    t.boolean "show_verification_status"
    t.boolean "created_via_api", default: false, null: false
    t.string "uphold_state_token"
    t.string "encrypted_uphold_code"
    t.string "encrypted_uphold_code_iv"
    t.string "encrypted_uphold_access_parameters"
    t.string "encrypted_uphold_access_parameters_iv"
    t.boolean "uphold_verified", default: false
    t.string "pending_email"
    t.boolean "supports_https", default: false
    t.boolean "host_connection_verified"
    t.string "detected_web_host"
    t.string "default_currency"
    t.string "auth_provider"
    t.string "auth_user_id"
    t.string "auth_name"
    t.string "auth_email"
    t.string "youtube_channel_id"
    t.string "brave_publisher_id_unnormalized"
    t.string "brave_publisher_id_error_code"
    t.datetime "uphold_updated_at"
    t.index ["brave_publisher_id"], name: "index_legacy_publishers_on_brave_publisher_id"
    t.index ["created_at"], name: "index_legacy_publishers_on_created_at"
    t.index ["verification_token"], name: "index_legacy_publishers_on_verification_token"
    t.index ["verified"], name: "index_legacy_publishers_on_verified"
    t.index ["youtube_channel_id"], name: "index_legacy_publishers_on_youtube_channel_id"
  end

  create_table "legacy_totp_registrations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "encrypted_secret"
    t.string "encrypted_secret_iv"
    t.uuid "publisher_id"
    t.datetime "last_logged_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publisher_id"], name: "index_legacy_totp_registrations_on_publisher_id"
  end

  create_table "legacy_youtube_channels", id: :string, force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "thumbnail_url"
    t.integer "subscriber_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_legacy_youtube_channels_on_id", unique: true
  end

  create_table "login_activities", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id"
    t.text "user_agent"
    t.text "accept_language"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_login_activities_on_created_at"
    t.index ["publisher_id"], name: "index_login_activities_on_publisher_id"
  end

  create_table "memberships", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organization_permissions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "organization_id"
    t.boolean "uphold_wallet", default: false, null: false
    t.boolean "offline_reporting", default: false, null: false
    t.boolean "referral_codes", default: false, null: false
    t.index ["organization_id"], name: "index_organization_permissions_on_organization_id", unique: true
  end

  create_table "organizations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payout_messages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "payout_report_id", null: false
    t.uuid "publisher_id", null: false
    t.text "message"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["payout_report_id"], name: "index_payout_messages_on_payout_report_id"
    t.index ["publisher_id"], name: "index_payout_messages_on_publisher_id"
  end

  create_table "payout_reports", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.boolean "final"
    t.decimal "fee_rate"
    t.text "encrypted_contents"
    t.string "encrypted_contents_iv"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "expected_num_payments"
    t.boolean "manual", default: false
    t.boolean "contents_rekeyed", default: false
  end

  create_table "paypal_connections", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "encrypted_refresh_token"
    t.string "encrypted_refresh_token_iv"
    t.text "country"
    t.boolean "verified_account"
    t.text "paypal_account_id"
    t.boolean "hidden", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "payer_id"
    t.boolean "refresh_token_rekeyed", default: false
    t.index ["user_id"], name: "index_paypal_connections_on_user_id"
  end

  create_table "potential_payments", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "payout_report_id", null: false
    t.uuid "publisher_id", null: false
    t.uuid "channel_id"
    t.string "kind", null: false
    t.string "name", null: false
    t.string "address", null: false
    t.string "amount", null: false
    t.string "fees", null: false
    t.string "url"
    t.string "uphold_status"
    t.boolean "reauthorization_needed"
    t.boolean "uphold_member"
    t.boolean "suspended"
    t.string "uphold_id"
    t.uuid "invoice_id"
    t.uuid "finalized_by_id"
    t.jsonb "channel_stats", default: {}
    t.text "channel_type"
    t.string "status"
    t.string "wallet_provider_id"
    t.integer "wallet_provider", limit: 2, default: 0
    t.boolean "paypal_bank_account_attached", default: false, null: false
    t.boolean "gemini_is_verified", default: false
    t.index ["channel_id"], name: "index_potential_payments_on_channel_id"
    t.index ["finalized_by_id"], name: "index_potential_payments_on_finalized_by_id"
    t.index ["invoice_id"], name: "index_potential_payments_on_invoice_id"
    t.index ["payout_report_id"], name: "index_potential_payments_on_payout_report_id"
    t.index ["publisher_id"], name: "index_potential_payments_on_publisher_id"
  end

  create_table "promo_campaigns", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "publisher_id"
    t.index ["name"], name: "index_promo_campaigns_on_name", unique: true
  end

  create_table "promo_registrations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "channel_id"
    t.string "promo_id", null: false
    t.string "referral_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "kind"
    t.jsonb "stats", default: "{}"
    t.uuid "promo_campaign_id"
    t.boolean "active", default: true, null: false
    t.uuid "publisher_id"
    t.string "installer_type"
    t.string "description"
    t.integer "aggregate_downloads", default: 0, null: false
    t.integer "aggregate_installs", default: 0, null: false
    t.integer "aggregate_confirmations", default: 0, null: false
    t.index ["channel_id"], name: "index_promo_registrations_on_channel_id", unique: true
    t.index ["kind", "created_at"], name: "index_promo_registrations_on_kind_and_created_at"
    t.index ["promo_campaign_id"], name: "index_promo_registrations_on_promo_campaign_id"
    t.index ["promo_id", "referral_code"], name: "index_promo_registrations_on_promo_id_and_referral_code", unique: true
    t.index ["publisher_id"], name: "index_promo_registrations_on_publisher_id"
    t.index ["referral_code"], name: "index_promo_registrations_on_referral_code"
  end

  create_table "publisher_notes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "created_by_id", null: false
    t.bigint "zendesk_ticket_id"
    t.bigint "zendesk_comment_id"
    t.uuid "thread_id"
    t.string "zendesk_to_email"
    t.string "zendesk_from_email"
    t.index ["created_by_id"], name: "index_publisher_notes_on_created_by_id"
    t.index ["publisher_id"], name: "index_publisher_notes_on_publisher_id"
    t.index ["thread_id"], name: "index_publisher_notes_on_thread_id"
    t.index ["zendesk_ticket_id", "zendesk_comment_id"], name: "index_publisher_notes_zendesk_ids", unique: true
  end

  create_table "publisher_status_updates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.uuid "publisher_note_id"
    t.index ["publisher_id", "created_at"], name: "index_publisher_status_updates_on_publisher_id_and_created_at"
    t.index ["publisher_note_id"], name: "index_publisher_status_updates_on_publisher_note_id"
  end

  create_table "publisher_whitelist_updates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id", null: false
    t.uuid "publisher_note_id"
    t.boolean "enabled", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at"], name: "index_publisher_whitelist_updates_on_created_at"
    t.index ["publisher_id"], name: "index_publisher_whitelist_updates_on_publisher_id"
    t.index ["publisher_note_id"], name: "index_publisher_whitelist_updates_on_publisher_note_id"
    t.index ["updated_at"], name: "index_publisher_whitelist_updates_on_updated_at"
  end

  create_table "publishers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "email"
    t.string "pending_email"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.boolean "created_via_api", default: false, null: false
    t.string "default_currency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "two_factor_prompted_at"
    t.boolean "promo_enabled_2018q1", default: false
    t.datetime "agreed_to_tos"
    t.string "promo_token_2018q1"
    t.text "role", default: "publisher"
    t.datetime "default_currency_confirmed_at"
    t.boolean "excluded_from_payout", default: false, null: false
    t.uuid "created_by_id"
    t.uuid "default_site_banner_id"
    t.boolean "default_site_banner_mode", default: false, null: false
    t.boolean "thirty_day_login", default: false, null: false
    t.boolean "subscribed_to_marketing_emails", default: false, null: false
    t.jsonb "feature_flags", default: {}
    t.string "selected_wallet_provider_type"
    t.uuid "selected_wallet_provider_id"
    t.string "bitflyer_deposit_id"
    t.index "lower((email)::text)", name: "index_publishers_on_lower_email", unique: true
    t.index ["created_at"], name: "index_publishers_on_created_at"
    t.index ["created_by_id"], name: "index_publishers_on_created_by_id"
    t.index ["pending_email"], name: "index_publishers_on_pending_email"
    t.index ["selected_wallet_provider_type", "selected_wallet_provider_id"], name: "publishers_wallet_provider_type"
  end

  create_table "reddit_channel_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "reddit_channel_id"
    t.string "auth_provider"
    t.string "name"
    t.string "channel_url"
    t.string "nickname"
    t.string "thumbnail_url"
    t.jsonb "stats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reddit_channel_id"], name: "index_reddit_channel_details_on_reddit_channel_id"
  end

  create_table "sessions", id: :serial, force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "site_banner_lookups", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "sha2_base16", null: false
    t.jsonb "derived_site_banner_info", null: false
    t.text "channel_identifier", null: false
    t.uuid "channel_id", null: false
    t.uuid "publisher_id", null: false
    t.uuid "wallet_address"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["channel_id"], name: "index_site_banner_lookups_on_channel_id"
    t.index ["channel_identifier"], name: "index_site_banner_lookups_on_channel_identifier"
    t.index ["publisher_id"], name: "index_site_banner_lookups_on_publisher_id"
    t.index ["sha2_base16"], name: "index_gin_site_banner_lookups_on_sha2_base16", using: :gin
    t.index ["sha2_base16"], name: "index_site_banner_lookups_on_sha2_base16"
  end

  create_table "site_banners", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.bigint "legacy_id"
    t.uuid "publisher_id", null: false
    t.text "title", null: false
    t.text "description", null: false
    t.integer "donation_amounts", array: true
    t.integer "default_donation"
    t.json "social_links"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "channel_id"
    t.index ["channel_id"], name: "index_site_banners_on_channel_id"
    t.index ["publisher_id"], name: "index_site_banners_on_publisher_id"
  end

  create_table "site_channel_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "brave_publisher_id"
    t.string "brave_publisher_id_unnormalized"
    t.string "brave_publisher_id_error_code"
    t.string "verification_token"
    t.string "verification_method"
    t.boolean "supports_https", default: false
    t.boolean "host_connection_verified"
    t.string "detected_web_host"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "https_error"
    t.jsonb "stats", default: "{}", null: false
    t.datetime "ads_enabled_at"
  end

  create_table "stripe_connections", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id", null: false
    t.string "encrypted_access_token"
    t.string "encrypted_access_token_iv"
    t.string "encrypted_refresh_token"
    t.string "encrypted_refresh_token_iv"
    t.string "stripe_user_id"
    t.string "display_name"
    t.string "state_token"
    t.string "scope"
    t.string "country"
    t.boolean "details_submitted"
    t.boolean "payouts_enabled"
    t.string "default_currency"
    t.jsonb "capabilities"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "access_token_rekeyed", default: false
    t.boolean "refresh_token_rekeyed", default: false
    t.index ["encrypted_access_token_iv"], name: "index_stripe_connections_on_encrypted_access_token_iv", unique: true
    t.index ["encrypted_refresh_token_iv"], name: "index_stripe_connections_on_encrypted_refresh_token_iv", unique: true
    t.index ["publisher_id"], name: "index_stripe_connections_on_publisher_id"
  end

  create_table "totp_registrations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "encrypted_secret"
    t.string "encrypted_secret_iv"
    t.uuid "publisher_id"
    t.datetime "last_logged_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "secret_rekeyed", default: false
    t.index ["publisher_id"], name: "index_totp_registrations_on_publisher_id"
  end

  create_table "twitch_channel_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "twitch_channel_id"
    t.string "auth_provider"
    t.string "auth_user_id"
    t.string "email"
    t.string "name"
    t.string "display_name"
    t.string "thumbnail_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "stats", default: "{}", null: false
    t.index ["twitch_channel_id"], name: "index_twitch_channel_details_on_twitch_channel_id"
  end

  create_table "twitter_channel_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "twitter_channel_id"
    t.string "auth_provider"
    t.string "auth_email"
    t.string "name"
    t.string "screen_name"
    t.string "thumbnail_url"
    t.jsonb "stats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["twitter_channel_id"], name: "index_twitter_channel_details_on_twitter_channel_id"
  end

  create_table "two_factor_authentication_removals", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id", null: false
    t.boolean "removal_completed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publisher_id"], name: "index_two_factor_authentication_removals_on_publisher_id"
  end

  create_table "u2f_registrations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "certificate"
    t.string "key_handle"
    t.string "public_key"
    t.integer "counter", null: false
    t.string "name"
    t.uuid "publisher_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key_handle"], name: "index_u2f_registrations_on_key_handle"
    t.index ["publisher_id"], name: "index_u2f_registrations_on_publisher_id"
  end

  create_table "uphold_connection_for_channels", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "uphold_connection_id", null: false
    t.uuid "channel_id", null: false
    t.string "currency"
    t.string "channel_identifier"
    t.string "card_id"
    t.string "address"
    t.uuid "uphold_id"
    t.index ["channel_id"], name: "index_uphold_connection_for_channels_on_channel_id"
    t.index ["channel_identifier", "currency", "uphold_connection_id"], name: "unique_uphold_connection_for_channels", unique: true
    t.index ["channel_identifier"], name: "index_uphold_connection_for_channels_on_channel_identifier"
    t.index ["currency"], name: "index_uphold_connection_for_channels_on_currency"
    t.index ["uphold_connection_id"], name: "index_uphold_connection_for_channels_on_uphold_connection_id"
    t.index ["uphold_id"], name: "index_uphold_connection_for_channels_on_uphold_id"
  end

  create_table "uphold_connections", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "uphold_state_token"
    t.boolean "uphold_verified", default: false
    t.boolean "is_member", default: false
    t.uuid "uphold_id"
    t.uuid "address"
    t.uuid "publisher_id"
    t.string "encrypted_uphold_code"
    t.string "encrypted_uphold_code_iv"
    t.string "encrypted_uphold_access_parameters"
    t.string "encrypted_uphold_access_parameters_iv"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.string "country"
    t.string "default_currency"
    t.datetime "default_currency_confirmed_at"
    t.datetime "member_at"
    t.datetime "send_emails", default: -> { "CURRENT_TIMESTAMP" }
    t.text "card_id"
    t.boolean "uphold_code_rekeyed", default: false
    t.boolean "uphold_access_parameters_rekeyed", default: false
    t.index ["card_id"], name: "index_uphold_connections_on_card_id"
    t.index ["publisher_id"], name: "index_uphold_connections_on_publisher_id", unique: true
  end

  create_table "uphold_status_reports", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "publisher_id"
    t.uuid "uphold_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_uphold_status_reports_on_created_at"
    t.index ["publisher_id"], name: "index_uphold_status_reports_on_publisher_id"
    t.index ["uphold_id"], name: "index_uphold_status_reports_on_uphold_id"
  end

  create_table "user_authentication_tokens", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "encrypted_authentication_token"
    t.string "encrypted_authentication_token_iv"
    t.datetime "authentication_token_expires_at"
    t.uuid "user_id", null: false
    t.boolean "authentication_token_rekeyed", default: false
    t.index ["user_id"], name: "index_user_authentication_tokens_on_user_id", unique: true
  end

  create_table "versions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "item_type", null: false
    t.uuid "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.text "object_changes"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "vimeo_channel_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "vimeo_channel_id"
    t.string "auth_provider"
    t.string "name"
    t.string "channel_url"
    t.string "nickname"
    t.string "thumbnail_url"
    t.jsonb "stats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "youtube_channel_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "youtube_channel_id"
    t.string "auth_provider"
    t.string "auth_user_id"
    t.string "auth_email"
    t.string "auth_name"
    t.string "title"
    t.string "description"
    t.string "thumbnail_url"
    t.integer "subscriber_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "stats", default: "{}", null: false
    t.index ["youtube_channel_id"], name: "index_youtube_channel_details_on_youtube_channel_id"
  end

  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cases", "publishers", column: "assignee_id"
  add_foreign_key "channel_transfers", "publishers", column: "transfer_from_id"
  add_foreign_key "channel_transfers", "publishers", column: "transfer_to_id"
  add_foreign_key "channels", "channels", column: "contested_by_channel_id"
  add_foreign_key "invoice_files", "publishers", column: "uploaded_by_id"
  add_foreign_key "invoices", "publishers", column: "finalized_by_id"
  add_foreign_key "invoices", "publishers", column: "paid_by_id"
  add_foreign_key "publisher_notes", "publishers", column: "created_by_id"
end
