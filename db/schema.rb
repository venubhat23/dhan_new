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

ActiveRecord::Schema[8.0].define(version: 2026_07_11_034311) do
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
    t.bigint "product_variant_id"
    t.index ["product_variant_id"], name: "index_booking_items_on_product_variant_id"
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
    t.boolean "is_b2b", default: false, null: false
    t.string "share_token"
    t.index ["booked_by"], name: "index_bookings_on_booked_by"
    t.index ["booking_schedule_id"], name: "index_bookings_on_booking_schedule_id"
    t.index ["cashfree_order_id"], name: "index_bookings_on_cashfree_order_id"
    t.index ["cashfree_payment_id"], name: "index_bookings_on_cashfree_payment_id"
    t.index ["courier_service"], name: "index_bookings_on_courier_service"
    t.index ["customer_id"], name: "index_bookings_on_customer_id"
    t.index ["delivery_person_id"], name: "index_bookings_on_delivery_person_id"
    t.index ["delivery_time"], name: "index_bookings_on_delivery_time"
    t.index ["expected_delivery_date"], name: "index_bookings_on_expected_delivery_date"
    t.index ["franchise_id"], name: "index_bookings_on_franchise_id"
    t.index ["invoice_number"], name: "index_bookings_on_invoice_number"
    t.index ["payment_gateway"], name: "index_bookings_on_payment_gateway"
    t.index ["share_token"], name: "index_bookings_on_share_token", unique: true
    t.index ["stage_updated_at"], name: "index_bookings_on_stage_updated_at"
    t.index ["stage_updated_by"], name: "index_bookings_on_stage_updated_by"
    t.index ["store_id"], name: "index_bookings_on_store_id"
    t.index ["tracking_number"], name: "index_bookings_on_tracking_number"
  end
