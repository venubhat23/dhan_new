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

ActiveRecord::Schema[8.0].define(version: 2026_03_24_011944) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "affiliates", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.string "email"
    t.string "mobile"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "pan_no"
    t.string "gst_no"
    t.decimal "commission_percentage", precision: 5, scale: 2
    t.string "bank_name"
    t.string "account_no"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.string "account_type"
    t.string "upi_id"
    t.boolean "status", default: true
    t.text "notes"
    t.string "auto_generated_password"
    t.date "joining_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "company_name"
    t.string "username"
    t.index ["email"], name: "index_affiliates_on_email", unique: true
    t.index ["mobile"], name: "index_affiliates_on_mobile", unique: true
  end

  create_table "banners", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "redirect_link"
    t.date "display_start_date"
    t.date "display_end_date"
    t.string "display_location"
    t.boolean "status", default: true
    t.integer "display_order", default: 0
    t.string "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_url"
    t.string "r2_image_url"
    t.index ["display_location"], name: "index_banners_on_display_location"
    t.index ["display_order"], name: "index_banners_on_display_order"
    t.index ["status"], name: "index_banners_on_status"
  end

  create_table "booking_invoices", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "customer_id"
    t.string "invoice_number"
    t.datetime "invoice_date"
    t.datetime "due_date"
    t.decimal "subtotal", precision: 10, scale: 2
    t.decimal "tax_amount", precision: 10, scale: 2
    t.decimal "discount_amount", precision: 10, scale: 2
    t.decimal "total_amount", precision: 10, scale: 2
    t.integer "payment_status"
    t.integer "status"
    t.text "notes"
    t.text "invoice_items"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "share_token"
    t.index ["booking_id"], name: "index_booking_invoices_on_booking_id"
    t.index ["customer_id"], name: "index_booking_invoices_on_customer_id"
    t.index ["invoice_number"], name: "index_booking_invoices_on_invoice_number", unique: true
    t.index ["share_token"], name: "index_booking_invoices_on_share_token", unique: true
  end

  create_table "booking_items", force: :cascade do |t|
    t.integer "booking_id"
    t.integer "product_id"
    t.decimal "quantity", precision: 8, scale: 2
    t.decimal "price"
    t.decimal "total"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "booking_schedules", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.string "schedule_type"
    t.string "frequency"
    t.date "start_date"
    t.date "end_date"
    t.integer "quantity"
    t.time "delivery_time"
    t.text "delivery_address"
    t.string "pincode"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "status"
    t.date "next_booking_date"
    t.integer "total_bookings_generated"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_booking_schedules_on_customer_id"
    t.index ["product_id"], name: "index_booking_schedules_on_product_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.integer "customer_id"
    t.integer "user_id"
    t.string "booking_number"
    t.datetime "booking_date"
    t.string "status"
    t.string "payment_method"
    t.string "payment_status"
    t.decimal "subtotal"
    t.decimal "tax_amount"
    t.decimal "discount_amount"
    t.decimal "total_amount"
    t.text "notes"
    t.text "booking_items"
    t.string "customer_name"
    t.string "customer_email"
    t.string "customer_phone"
    t.text "delivery_address"
    t.boolean "invoice_generated"
    t.string "invoice_number"
    t.decimal "cash_received"
    t.decimal "change_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "booking_schedule_id"
    t.string "stage"
    t.string "courier_service"
    t.string "tracking_number"
    t.decimal "shipping_charges", precision: 10, scale: 2
    t.date "expected_delivery_date"
    t.string "delivery_person"
    t.string "delivery_contact"
    t.string "delivered_to"
    t.datetime "delivery_time"
    t.integer "customer_satisfaction"
    t.string "processing_team"
    t.datetime "expected_completion_time"
    t.string "estimated_processing_time"
    t.string "estimated_delivery_time"
    t.decimal "package_weight", precision: 8, scale: 2
    t.string "package_dimensions"
    t.string "quality_status"
    t.string "cancellation_reason"
    t.string "return_reason"
    t.string "return_condition"
    t.decimal "refund_amount", precision: 10, scale: 2
    t.string "refund_method"
    t.text "transition_notes"
    t.text "stage_history"
    t.datetime "stage_updated_at"
    t.integer "stage_updated_by"
    t.bigint "store_id"
    t.integer "subscription_id"
    t.boolean "is_subscription"
    t.decimal "final_amount_after_discount"
    t.bigint "delivery_person_id"
    t.bigint "franchise_id"
    t.boolean "quick_invoice", default: false
    t.string "booked_by", default: "admin"
    t.text "selected_shop_address"
    t.text "delivery_store"
    t.string "cashfree_order_id"
    t.string "payment_session_id"
    t.string "cashfree_payment_id"
    t.text "gateway_response"
    t.string "payment_gateway", default: "cash"
    t.datetime "payment_initiated_at"
    t.datetime "payment_completed_at"
    t.index ["booked_by"], name: "index_bookings_on_booked_by"
    t.index ["booking_schedule_id"], name: "index_bookings_on_booking_schedule_id"
    t.index ["cashfree_order_id"], name: "index_bookings_on_cashfree_order_id"
    t.index ["cashfree_payment_id"], name: "index_bookings_on_cashfree_payment_id"
    t.index ["courier_service"], name: "index_bookings_on_courier_service"
    t.index ["delivery_person_id"], name: "index_bookings_on_delivery_person_id"
    t.index ["delivery_time"], name: "index_bookings_on_delivery_time"
    t.index ["expected_delivery_date"], name: "index_bookings_on_expected_delivery_date"
    t.index ["franchise_id"], name: "index_bookings_on_franchise_id"
    t.index ["payment_gateway"], name: "index_bookings_on_payment_gateway"
    t.index ["stage_updated_at"], name: "index_bookings_on_stage_updated_at"
    t.index ["stage_updated_by"], name: "index_bookings_on_stage_updated_by"
    t.index ["store_id"], name: "index_bookings_on_store_id"
    t.index ["tracking_number"], name: "index_bookings_on_tracking_number"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "image"
    t.boolean "status", default: true
    t.integer "display_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_backup_url"
    t.index ["display_order"], name: "index_categories_on_display_order"
    t.index ["status"], name: "index_categories_on_status"
  end

  create_table "client_requests", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "status", default: "pending"
    t.string "priority", default: "medium"
    t.bigint "customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stage", default: "new"
    t.datetime "stage_updated_at"
    t.text "stage_history"
    t.integer "assignee_id"
    t.string "department"
    t.datetime "estimated_resolution_time"
    t.datetime "actual_resolution_time"
    t.string "name"
    t.string "email"
    t.string "phone_number"
    t.string "ticket_number"
    t.text "admin_response"
    t.integer "resolved_by_id"
    t.datetime "submitted_at"
    t.datetime "resolved_at"
    t.index ["assignee_id"], name: "index_client_requests_on_assignee_id"
    t.index ["customer_id"], name: "index_client_requests_on_customer_id"
    t.index ["department"], name: "index_client_requests_on_department"
    t.index ["estimated_resolution_time"], name: "index_client_requests_on_estimated_resolution_time"
    t.index ["stage"], name: "index_client_requests_on_stage"
    t.index ["ticket_number"], name: "index_client_requests_on_ticket_number", unique: true
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code"
    t.text "description"
    t.string "discount_type"
    t.decimal "discount_value"
    t.decimal "minimum_amount"
    t.decimal "maximum_discount"
    t.integer "usage_limit"
    t.integer "used_count"
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.boolean "status"
    t.text "applicable_products"
    t.text "applicable_categories"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
  end

  create_table "customer_addresses", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name"
    t.string "mobile"
    t.string "address_type"
    t.text "address"
    t.string "landmark"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.decimal "latitude"
    t.decimal "longitude"
    t.boolean "is_default"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_addresses_on_customer_id"
  end

  create_table "customer_formats", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "pattern"
    t.decimal "quantity"
    t.bigint "product_id", null: false
    t.bigint "delivery_person_id", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "days"
    t.index ["customer_id"], name: "index_customer_formats_on_customer_id"
    t.index ["delivery_person_id"], name: "index_customer_formats_on_delivery_person_id"
    t.index ["product_id"], name: "index_customer_formats_on_product_id"
  end

  create_table "customer_wallets", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.decimal "balance", precision: 10, scale: 2, default: "0.0"
    t.boolean "status", default: true
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_wallets_on_customer_id", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "mobile"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "longitude", precision: 10, scale: 8
    t.decimal "latitude", precision: 10, scale: 8
    t.string "whatsapp_number"
    t.string "auto_generated_password"
    t.datetime "location_obtained_at"
    t.decimal "location_accuracy", precision: 8, scale: 2
    t.string "password_digest"
    t.string "middle_name"
    t.text "address"
    t.date "birth_date"
    t.string "gender"
    t.string "marital_status"
    t.string "pan_no"
    t.string "gst_no"
    t.string "company_name"
    t.string "occupation"
    t.decimal "annual_income"
    t.string "emergency_contact_name"
    t.string "emergency_contact_number"
    t.string "blood_group"
    t.string "nationality"
    t.string "preferred_language"
    t.text "notes"
    t.boolean "status", default: true, null: false
    t.boolean "is_registered_by_mobile"
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.index ["latitude", "longitude"], name: "index_customers_on_location"
    t.index ["whatsapp_number"], name: "index_customers_on_whatsapp_number"
  end

  create_table "delivery_people", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "mobile"
    t.string "vehicle_type"
    t.string "vehicle_number"
    t.string "license_number"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "emergency_contact_name"
    t.string "emergency_contact_mobile"
    t.date "joining_date"
    t.decimal "salary"
    t.boolean "status"
    t.string "profile_picture"
    t.string "bank_name"
    t.string "account_no"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.text "delivery_areas"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.string "auto_generated_password"
  end

  create_table "delivery_rules", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "rule_type", null: false
    t.text "location_data"
    t.boolean "is_excluded", default: false
    t.integer "delivery_days"
    t.decimal "delivery_charge", precision: 8, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_delivery_rules_on_product_id"
    t.index ["rule_type"], name: "index_delivery_rules_on_rule_type"
  end

  create_table "device_tokens", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "delivery_person_id", null: false
    t.string "token"
    t.string "device_type"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_device_tokens_on_customer_id"
    t.index ["delivery_person_id"], name: "index_device_tokens_on_delivery_person_id"
  end

  create_table "franchises", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "mobile"
    t.string "contact_person_name"
    t.string "business_type"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "pan_no"
    t.string "gst_no"
    t.string "license_no"
    t.date "establishment_date"
    t.string "territory"
    t.decimal "franchise_fee"
    t.decimal "commission_percentage"
    t.boolean "status"
    t.text "notes"
    t.string "password_digest"
    t.string "auto_generated_password"
    t.decimal "longitude"
    t.decimal "latitude"
    t.string "whatsapp_number"
    t.string "profile_image"
    t.text "business_documents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["email"], name: "index_franchises_on_email", unique: true
    t.index ["mobile"], name: "index_franchises_on_mobile", unique: true
    t.index ["pan_no"], name: "index_franchises_on_pan_no", unique: true
    t.index ["user_id"], name: "index_franchises_on_user_id"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "milk_delivery_task_id"
    t.text "description"
    t.decimal "quantity"
    t.decimal "unit_price"
    t.decimal "total_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_id"
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
    t.index ["milk_delivery_task_id"], name: "index_invoice_items_on_milk_delivery_task_id"
    t.index ["product_id"], name: "index_invoice_items_on_product_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.string "invoice_number"
    t.string "payout_type"
    t.integer "payout_id"
    t.decimal "total_amount"
    t.string "status"
    t.date "invoice_date"
    t.date "due_date"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "customer_id"
    t.integer "payment_status"
    t.string "share_token"
    t.boolean "quick_invoice", default: false
    t.decimal "paid_amount", precision: 10, scale: 2, default: "0.0"
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["share_token"], name: "index_invoices_on_share_token", unique: true
  end

  create_table "leads", force: :cascade do |t|
    t.string "name"
    t.string "contact_number"
    t.string "email"
    t.string "current_stage"
    t.string "lead_source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "product_category"
    t.string "product_subcategory"
    t.string "customer_type"
    t.integer "affiliate_id"
    t.boolean "is_direct"
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.string "company_name"
    t.string "gender"
    t.string "marital_status"
    t.string "pan_no"
    t.string "gst_no"
    t.decimal "height"
    t.decimal "weight"
    t.decimal "annual_income"
    t.string "business_job"
  end

  create_table "milk_delivery_tasks", force: :cascade do |t|
    t.bigint "subscription_id"
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 10, scale: 2
    t.string "unit"
    t.date "delivery_date"
    t.bigint "delivery_person_id"
    t.string "status", default: "pending"
    t.datetime "assigned_at"
    t.datetime "completed_at"
    t.text "delivery_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "invoiced", default: false
    t.datetime "invoiced_at"
    t.index ["customer_id", "delivery_date"], name: "index_milk_delivery_tasks_on_customer_id_and_delivery_date"
    t.index ["customer_id"], name: "index_milk_delivery_tasks_on_customer_id"
    t.index ["delivery_date"], name: "index_milk_delivery_tasks_on_delivery_date"
    t.index ["delivery_person_id", "delivery_date"], name: "idx_on_delivery_person_id_delivery_date_8b580f1b82"
    t.index ["delivery_person_id"], name: "index_milk_delivery_tasks_on_delivery_person_id"
    t.index ["product_id"], name: "index_milk_delivery_tasks_on_product_id"
    t.index ["status"], name: "index_milk_delivery_tasks_on_status"
    t.index ["subscription_id"], name: "index_milk_delivery_tasks_on_subscription_id"
  end

  create_table "milk_subscriptions", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 10, scale: 2
    t.string "unit", default: "liter"
    t.date "start_date"
    t.date "end_date"
    t.string "delivery_time", default: "morning"
    t.string "delivery_pattern", default: "daily"
    t.text "specific_dates"
    t.decimal "total_amount", precision: 10, scale: 2
    t.string "status", default: "active"
    t.boolean "is_active", default: true
    t.integer "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "delivery_person_id"
    t.index ["customer_id"], name: "index_milk_subscriptions_on_customer_id"
    t.index ["product_id"], name: "index_milk_subscriptions_on_product_id"
    t.index ["start_date", "end_date"], name: "idx_milk_subscriptions_dates"
    t.index ["status"], name: "idx_milk_subscriptions_status"
  end

  create_table "notes", force: :cascade do |t|
    t.string "title", null: false
    t.string "paid_to", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "payment_method", null: false
    t.string "reference_number"
    t.text "description"
    t.string "status", default: "pending"
    t.date "note_date", default: -> { "CURRENT_DATE" }, null: false
    t.bigint "created_by_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "paid_from"
    t.string "paid_to_category"
    t.index ["created_by_user_id"], name: "index_notes_on_created_by_user_id"
    t.index ["note_date"], name: "index_notes_on_note_date"
    t.index ["payment_method"], name: "index_notes_on_payment_method"
    t.index ["status"], name: "index_notes_on_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "title"
    t.text "message"
    t.string "notification_type"
    t.json "data"
    t.boolean "read"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_notifications_on_customer_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.integer "order_id"
    t.integer "product_id"
    t.integer "quantity"
    t.decimal "price"
    t.decimal "total"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer "customer_id"
    t.integer "user_id"
    t.string "order_number"
    t.datetime "order_date"
    t.string "status"
    t.string "payment_method"
    t.string "payment_status"
    t.decimal "subtotal"
    t.decimal "tax_amount"
    t.decimal "discount_amount"
    t.decimal "shipping_amount"
    t.decimal "total_amount"
    t.text "notes"
    t.text "order_items"
    t.string "customer_name"
    t.string "customer_email"
    t.string "customer_phone"
    t.text "delivery_address"
    t.string "tracking_number"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "processing_notes"
    t.integer "estimated_processing_time"
    t.datetime "processing_started_at"
    t.string "packed_by"
    t.decimal "package_weight"
    t.string "package_dimensions"
    t.text "packing_notes"
    t.datetime "packed_at"
    t.string "shipping_carrier"
    t.date "estimated_delivery_date"
    t.decimal "shipping_cost"
    t.text "shipping_notes"
    t.datetime "shipped_at"
    t.string "delivered_to"
    t.string "delivery_location"
    t.text "delivery_notes"
    t.datetime "cancelled_at"
    t.string "cancellation_reason"
    t.string "refund_method"
    t.decimal "refund_amount"
    t.text "cancellation_notes"
    t.boolean "invoice_generated", default: false
    t.string "invoice_number"
    t.decimal "cash_received", precision: 10, scale: 2
    t.decimal "change_amount", precision: 10, scale: 2
    t.string "order_stage", default: "draft"
    t.datetime "booking_date"
    t.integer "booking_id"
    t.index ["booking_id"], name: "index_orders_on_booking_id"
  end

  create_table "pending_amounts", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.decimal "amount"
    t.text "description"
    t.date "pending_date"
    t.integer "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_pending_amounts_on_customer_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "name", null: false
    t.string "resource"
    t.string "action"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_permissions_on_name", unique: true
    t.index ["resource", "action"], name: "index_permissions_on_resource_and_action"
  end

  create_table "product_ratings", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "customer_id"
    t.bigint "user_id"
    t.integer "rating", null: false
    t.text "comment"
    t.integer "status", default: 0
    t.string "reviewer_name"
    t.string "reviewer_email"
    t.boolean "verified_purchase", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_product_ratings_on_customer_id"
    t.index ["product_id", "rating"], name: "index_product_ratings_on_product_id_and_rating"
    t.index ["product_id", "status"], name: "index_product_ratings_on_product_id_and_status"
    t.index ["product_id"], name: "index_product_ratings_on_product_id"
    t.index ["user_id"], name: "index_product_ratings_on_user_id"
  end

  create_table "product_reviews", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "customer_id"
    t.bigint "user_id"
    t.integer "rating", null: false
    t.text "comment"
    t.string "reviewer_name"
    t.string "reviewer_email"
    t.integer "status", default: 0
    t.boolean "verified_purchase", default: false
    t.integer "helpful_count", default: 0
    t.text "pros"
    t.text "cons"
    t.string "title"
    t.json "images_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "product_id"], name: "index_product_reviews_on_customer_id_and_product_id", unique: true, where: "(customer_id IS NOT NULL)"
    t.index ["customer_id"], name: "index_product_reviews_on_customer_id"
    t.index ["product_id", "created_at"], name: "index_product_reviews_on_product_id_and_created_at"
    t.index ["product_id", "rating"], name: "index_product_reviews_on_product_id_and_rating"
    t.index ["product_id", "status"], name: "index_product_reviews_on_product_id_and_status"
    t.index ["product_id"], name: "index_product_reviews_on_product_id"
    t.index ["user_id"], name: "index_product_reviews_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "category_id", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.decimal "discount_price", precision: 10, scale: 2
    t.integer "stock", default: 0
    t.string "status", default: "active"
    t.string "sku", null: false
    t.decimal "weight", precision: 8, scale: 3
    t.string "dimensions"
    t.text "meta_title"
    t.text "meta_description"
    t.text "tags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "discount_type"
    t.decimal "discount_value", precision: 10, scale: 2
    t.decimal "original_price", precision: 10, scale: 2
    t.decimal "discount_amount", precision: 10, scale: 2
    t.boolean "is_discounted", default: false
    t.boolean "gst_enabled", default: false
    t.decimal "gst_percentage", precision: 5, scale: 2
    t.decimal "cgst_percentage", precision: 5, scale: 2
    t.decimal "sgst_percentage", precision: 5, scale: 2
    t.decimal "igst_percentage", precision: 5, scale: 2
    t.decimal "gst_amount", precision: 10, scale: 2
    t.decimal "cgst_amount", precision: 10, scale: 2
    t.decimal "sgst_amount", precision: 10, scale: 2
    t.decimal "igst_amount", precision: 10, scale: 2
    t.decimal "final_amount_with_gst", precision: 10, scale: 2
    t.decimal "buying_price", precision: 10, scale: 2
    t.decimal "yesterday_price", precision: 10, scale: 2
    t.decimal "today_price", precision: 10, scale: 2
    t.decimal "price_change_percentage", precision: 5, scale: 2
    t.datetime "last_price_update"
    t.text "price_history"
    t.boolean "is_occasional_product", default: false, null: false
    t.datetime "occasional_start_date"
    t.datetime "occasional_end_date"
    t.text "occasional_description"
    t.boolean "occasional_auto_hide", default: true, null: false
    t.string "product_type", default: "Grocery"
    t.string "occasional_schedule_type"
    t.string "occasional_recurring_from_day"
    t.time "occasional_recurring_from_time"
    t.string "occasional_recurring_to_day"
    t.time "occasional_recurring_to_time"
    t.boolean "is_subscription_enabled", default: false
    t.string "unit_type"
    t.integer "minimum_stock_alert"
    t.decimal "default_selling_price"
    t.string "hsn_code"
    t.string "image_url"
    t.text "additional_images_urls"
    t.integer "display_order"
    t.decimal "base_price_excluding_gst"
    t.string "r2_image_url"
    t.text "r2_additional_images"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["is_occasional_product", "occasional_start_date", "occasional_end_date"], name: "index_products_on_occasional_dates"
    t.index ["is_occasional_product"], name: "index_products_on_is_occasional_product"
    t.index ["is_subscription_enabled"], name: "index_products_on_is_subscription_enabled"
    t.index ["last_price_update"], name: "index_products_on_last_price_update"
    t.index ["name"], name: "index_products_on_name"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["status"], name: "index_products_on_status"
  end

  create_table "referrals", force: :cascade do |t|
    t.bigint "affiliate_id"
    t.string "referred_name"
    t.string "referred_mobile"
    t.string "referred_email"
    t.date "referral_date"
    t.string "status"
    t.text "notes"
    t.datetime "converted_at"
    t.bigint "customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "referring_customer_id"
    t.string "referral_source", default: "affiliate"
    t.index ["affiliate_id"], name: "index_referrals_on_affiliate_id"
    t.index ["customer_id"], name: "index_referrals_on_customer_id"
    t.index ["referral_source"], name: "index_referrals_on_referral_source"
    t.index ["referring_customer_id"], name: "index_referrals_on_referring_customer_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.boolean "status"
    t.text "permissions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sale_items", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "product_id", null: false
    t.bigint "stock_batch_id", null: false
    t.decimal "quantity"
    t.decimal "selling_price"
    t.decimal "purchase_price"
    t.decimal "profit_amount"
    t.decimal "line_total"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_sale_items_on_booking_id"
    t.index ["product_id"], name: "index_sale_items_on_product_id"
    t.index ["stock_batch_id"], name: "index_sale_items_on_stock_batch_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stock_batches", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "vendor_id", null: false
    t.bigint "vendor_purchase_id"
    t.decimal "quantity_purchased"
    t.decimal "quantity_remaining"
    t.decimal "purchase_price"
    t.decimal "selling_price"
    t.date "batch_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_stock_batches_on_product_id"
    t.index ["vendor_id"], name: "index_stock_batches_on_vendor_id"
    t.index ["vendor_purchase_id"], name: "index_stock_batches_on_vendor_purchase_id"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "reference_type", null: false
    t.integer "reference_id"
    t.string "movement_type", null: false
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.decimal "stock_before", precision: 10, scale: 2, null: false
    t.decimal "stock_after", precision: 10, scale: 2, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "idx_stock_movements_created_at"
    t.index ["movement_type"], name: "idx_stock_movements_movement_type"
    t.index ["product_id", "created_at"], name: "idx_stock_movements_product_created"
    t.index ["product_id"], name: "idx_stock_movements_product_id"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["reference_type", "reference_id"], name: "idx_stock_movements_ref_type_id"
  end

  create_table "stores", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "contact_person"
    t.string "contact_mobile"
    t.string "email"
    t.boolean "status"
    t.string "gst_no"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sub_agents", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.string "email"
    t.string "mobile"
    t.string "password_digest"
    t.string "plain_password"
    t.string "original_password"
    t.integer "role_id"
    t.string "gender"
    t.date "birth_date"
    t.string "pan_no"
    t.string "aadhar_no"
    t.string "gst_no"
    t.string "company_name"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "country"
    t.string "profile_picture"
    t.string "bank_name"
    t.string "account_no"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.string "account_type"
    t.string "upi_id"
    t.string "emergency_contact_name"
    t.string "emergency_contact_mobile"
    t.date "joining_date"
    t.decimal "salary", precision: 10, scale: 2
    t.text "notes"
    t.integer "status", default: 0
    t.integer "distributor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aadhar_no"], name: "index_sub_agents_on_aadhar_no", unique: true
    t.index ["email"], name: "index_sub_agents_on_email", unique: true
    t.index ["mobile"], name: "index_sub_agents_on_mobile", unique: true
    t.index ["pan_no"], name: "index_sub_agents_on_pan_no", unique: true
  end

  create_table "subscription_templates", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.bigint "delivery_person_id"
    t.decimal "quantity", precision: 8, scale: 2
    t.string "unit"
    t.decimal "price", precision: 10, scale: 2
    t.string "delivery_time"
    t.boolean "is_active"
    t.string "template_name"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_subscription_templates_on_customer_id"
    t.index ["delivery_person_id"], name: "index_subscription_templates_on_delivery_person_id"
    t.index ["product_id"], name: "index_subscription_templates_on_product_id"
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key"
    t.text "value"
    t.string "setting_type"
    t.text "description"
    t.decimal "default_main_agent_commission"
    t.decimal "default_affiliate_commission"
    t.decimal "default_ambassador_commission"
    t.decimal "default_company_expenses"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "business_name"
    t.text "address"
    t.string "mobile"
    t.string "email"
    t.string "gstin"
    t.string "pan_number"
    t.string "account_holder_name"
    t.string "bank_name"
    t.string "account_number"
    t.string "ifsc_code"
    t.string "upi_id"
    t.string "qr_code_path"
    t.text "terms_and_conditions"
    t.boolean "collect_from_store_enabled"
    t.boolean "delivery_only_at_shop"
    t.text "shop_addresses"
    t.index ["key"], name: "index_system_settings_on_key", unique: true
  end

  create_table "user_roles", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_user_roles_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "mobile", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "middle_name"
    t.string "encrypted_password"
    t.string "user_type", default: "admin"
    t.string "role", default: "super_admin"
    t.integer "role_id"
    t.boolean "status", default: true
    t.boolean "is_active", default: true
    t.boolean "is_verified", default: false
    t.date "birth_date"
    t.string "gender"
    t.string "pan_no"
    t.string "aadhar_no"
    t.string "gst_no"
    t.string "company_name"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "country", default: "India"
    t.string "profile_picture"
    t.string "bank_name"
    t.string "account_no"
    t.string "ifsc_code"
    t.string "account_holder_name"
    t.string "account_type"
    t.string "upi_id"
    t.string "emergency_contact_name"
    t.string "emergency_contact_mobile"
    t.string "department"
    t.string "designation"
    t.date "joining_date"
    t.decimal "salary", precision: 10, scale: 2
    t.string "employee_id"
    t.integer "reporting_manager_id"
    t.text "permissions"
    t.text "sidebar_permissions"
    t.datetime "last_login_at"
    t.integer "login_count", default: 0
    t.datetime "email_verified_at"
    t.datetime "mobile_verified_at"
    t.boolean "two_factor_enabled", default: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unlock_token"
    t.datetime "locked_at"
    t.integer "failed_attempts", default: 0
    t.text "notes"
    t.integer "created_by"
    t.integer "updated_by"
    t.datetime "deleted_at"
    t.string "original_password"
    t.string "authenticatable_type"
    t.bigint "authenticatable_id"
    t.index ["aadhar_no"], name: "index_users_on_aadhar_no", unique: true
    t.index ["authenticatable_type", "authenticatable_id"], name: "index_users_on_authenticatable"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employee_id"], name: "index_users_on_employee_id", unique: true
    t.index ["is_active"], name: "index_users_on_is_active"
    t.index ["mobile"], name: "index_users_on_mobile", unique: true
    t.index ["pan_no"], name: "index_users_on_pan_no", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["user_type"], name: "index_users_on_user_type"
  end

  create_table "vendor_invoices", force: :cascade do |t|
    t.bigint "vendor_purchase_id", null: false
    t.string "invoice_number"
    t.decimal "total_amount"
    t.integer "status"
    t.date "invoice_date"
    t.string "share_token"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_number"], name: "index_vendor_invoices_on_invoice_number", unique: true
    t.index ["share_token"], name: "index_vendor_invoices_on_share_token", unique: true
    t.index ["vendor_purchase_id"], name: "index_vendor_invoices_on_vendor_purchase_id"
  end

  create_table "vendor_payments", force: :cascade do |t|
    t.bigint "vendor_id", null: false
    t.bigint "vendor_purchase_id", null: false
    t.decimal "amount_paid"
    t.date "payment_date"
    t.string "payment_mode"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vendor_id"], name: "index_vendor_payments_on_vendor_id"
    t.index ["vendor_purchase_id"], name: "index_vendor_payments_on_vendor_purchase_id"
  end

  create_table "vendor_purchase_items", force: :cascade do |t|
    t.bigint "vendor_purchase_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity"
    t.decimal "purchase_price"
    t.decimal "selling_price"
    t.decimal "line_total"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_vendor_purchase_items_on_product_id"
    t.index ["vendor_purchase_id"], name: "index_vendor_purchase_items_on_vendor_purchase_id"
  end

  create_table "vendor_purchases", force: :cascade do |t|
    t.bigint "vendor_id", null: false
    t.date "purchase_date"
    t.decimal "total_amount"
    t.decimal "paid_amount"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vendor_id"], name: "index_vendor_purchases_on_vendor_id"
  end

  create_table "vendors", force: :cascade do |t|
    t.string "name"
    t.string "phone"
    t.string "email"
    t.text "address"
    t.string "payment_type"
    t.decimal "opening_balance"
    t.boolean "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "wallet_transactions", force: :cascade do |t|
    t.bigint "customer_wallet_id", null: false
    t.string "transaction_type"
    t.decimal "amount", precision: 10, scale: 2
    t.decimal "balance_after", precision: 10, scale: 2
    t.string "description"
    t.string "reference_number"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_wallet_id"], name: "index_wallet_transactions_on_customer_wallet_id"
    t.index ["reference_number"], name: "index_wallet_transactions_on_reference_number", unique: true
    t.index ["transaction_type"], name: "index_wallet_transactions_on_transaction_type"
  end

  create_table "wishlists", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_wishlists_on_customer_id"
    t.index ["product_id"], name: "index_wishlists_on_product_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "booking_invoices", "bookings"
  add_foreign_key "booking_invoices", "customers"
  add_foreign_key "booking_schedules", "customers"
  add_foreign_key "booking_schedules", "products"
  add_foreign_key "bookings", "booking_schedules"
  add_foreign_key "bookings", "delivery_people"
  add_foreign_key "bookings", "franchises"
  add_foreign_key "bookings", "stores"
  add_foreign_key "client_requests", "customers"
  add_foreign_key "client_requests", "users", column: "assignee_id"
  add_foreign_key "customer_addresses", "customers"
  add_foreign_key "customer_formats", "customers"
  add_foreign_key "customer_formats", "delivery_people"
  add_foreign_key "customer_formats", "products"
  add_foreign_key "customer_wallets", "customers"
  add_foreign_key "delivery_rules", "products"
  add_foreign_key "device_tokens", "customers"
  add_foreign_key "device_tokens", "delivery_people"
  add_foreign_key "franchises", "users"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "invoice_items", "milk_delivery_tasks"
  add_foreign_key "invoice_items", "products"
  add_foreign_key "milk_delivery_tasks", "customers"
  add_foreign_key "milk_delivery_tasks", "delivery_people"
  add_foreign_key "milk_delivery_tasks", "milk_subscriptions", column: "subscription_id"
  add_foreign_key "milk_delivery_tasks", "products"
  add_foreign_key "milk_subscriptions", "customers"
  add_foreign_key "milk_subscriptions", "delivery_people", name: "fk_milk_subscriptions_delivery_person"
  add_foreign_key "milk_subscriptions", "products"
  add_foreign_key "notes", "users", column: "created_by_user_id"
  add_foreign_key "notifications", "customers"
  add_foreign_key "pending_amounts", "customers"
  add_foreign_key "product_ratings", "customers"
  add_foreign_key "product_ratings", "products"
  add_foreign_key "product_ratings", "users"
  add_foreign_key "product_reviews", "customers"
  add_foreign_key "product_reviews", "products"
  add_foreign_key "product_reviews", "users"
  add_foreign_key "products", "categories"
  add_foreign_key "referrals", "affiliates"
  add_foreign_key "referrals", "customers"
  add_foreign_key "referrals", "customers", column: "referring_customer_id"
  add_foreign_key "sale_items", "bookings"
  add_foreign_key "sale_items", "products"
  add_foreign_key "sale_items", "stock_batches"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "stock_batches", "products"
  add_foreign_key "stock_batches", "vendor_purchases"
  add_foreign_key "stock_batches", "vendors"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "subscription_templates", "customers"
  add_foreign_key "subscription_templates", "delivery_people"
  add_foreign_key "subscription_templates", "products"
  add_foreign_key "vendor_invoices", "vendor_purchases"
  add_foreign_key "vendor_payments", "vendor_purchases"
  add_foreign_key "vendor_payments", "vendors"
  add_foreign_key "vendor_purchase_items", "products"
  add_foreign_key "vendor_purchase_items", "vendor_purchases"
  add_foreign_key "vendor_purchases", "vendors"
  add_foreign_key "wallet_transactions", "customer_wallets"
  add_foreign_key "wishlists", "customers"
  add_foreign_key "wishlists", "products"
end
