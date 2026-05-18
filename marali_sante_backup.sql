--
-- PostgreSQL database dump
--

\restrict CQmTajPxHeTjdUzdMB4tzkF3gx5ZJtC4dDG1I0DqsijuozRMypUN9PnXwIEEJyW

-- Dumped from database version 18.3 (Debian 18.3-1.pgdg12+1)
-- Dumped by pg_dump version 18.3 (Ubuntu 18.3-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: marali_sante_user
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO marali_sante_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.active_storage_attachments OWNER TO marali_sante_user;

--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.active_storage_attachments_id_seq OWNER TO marali_sante_user;

--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.active_storage_blobs OWNER TO marali_sante_user;

--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.active_storage_blobs_id_seq OWNER TO marali_sante_user;

--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


ALTER TABLE public.active_storage_variant_records OWNER TO marali_sante_user;

--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNER TO marali_sante_user;

--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: affiliates; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.affiliates (
    id bigint NOT NULL,
    first_name character varying,
    last_name character varying,
    middle_name character varying,
    email character varying,
    mobile character varying,
    address text,
    city character varying,
    state character varying,
    pincode character varying,
    pan_no character varying,
    gst_no character varying,
    commission_percentage numeric(5,2),
    bank_name character varying,
    account_no character varying,
    ifsc_code character varying,
    account_holder_name character varying,
    account_type character varying,
    upi_id character varying,
    status boolean DEFAULT true,
    notes text,
    auto_generated_password character varying,
    joining_date date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    company_name character varying,
    username character varying
);


ALTER TABLE public.affiliates OWNER TO marali_sante_user;

--
-- Name: affiliates_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.affiliates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.affiliates_id_seq OWNER TO marali_sante_user;

--
-- Name: affiliates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.affiliates_id_seq OWNED BY public.affiliates.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.ar_internal_metadata OWNER TO marali_sante_user;

--
-- Name: banners; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.banners (
    id bigint NOT NULL,
    title character varying,
    description text,
    redirect_link character varying,
    display_start_date date,
    display_end_date date,
    display_location character varying,
    status boolean DEFAULT true,
    display_order integer DEFAULT 0,
    image character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    image_url character varying,
    r2_image_url character varying
);


ALTER TABLE public.banners OWNER TO marali_sante_user;

--
-- Name: banners_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.banners_id_seq OWNER TO marali_sante_user;

--
-- Name: banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.banners_id_seq OWNED BY public.banners.id;


--
-- Name: booking_invoices; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.booking_invoices (
    id bigint NOT NULL,
    booking_id bigint NOT NULL,
    customer_id bigint,
    invoice_number character varying,
    invoice_date timestamp(6) without time zone,
    due_date timestamp(6) without time zone,
    subtotal numeric(10,2),
    tax_amount numeric(10,2),
    discount_amount numeric(10,2),
    total_amount numeric(10,2),
    payment_status integer,
    status integer,
    notes text,
    invoice_items text,
    paid_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    share_token character varying
);


ALTER TABLE public.booking_invoices OWNER TO marali_sante_user;

--
-- Name: booking_invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.booking_invoices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.booking_invoices_id_seq OWNER TO marali_sante_user;

--
-- Name: booking_invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.booking_invoices_id_seq OWNED BY public.booking_invoices.id;


--
-- Name: booking_items; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.booking_items (
    id bigint NOT NULL,
    booking_id integer,
    product_id integer,
    quantity numeric(8,2),
    price numeric,
    total numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.booking_items OWNER TO marali_sante_user;

--
-- Name: booking_items_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.booking_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.booking_items_id_seq OWNER TO marali_sante_user;

--
-- Name: booking_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.booking_items_id_seq OWNED BY public.booking_items.id;


--
-- Name: booking_schedules; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.booking_schedules (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    product_id bigint NOT NULL,
    schedule_type character varying,
    frequency character varying,
    start_date date,
    end_date date,
    quantity integer,
    delivery_time time without time zone,
    delivery_address text,
    pincode character varying,
    latitude numeric,
    longitude numeric,
    status character varying,
    next_booking_date date,
    total_bookings_generated integer,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.booking_schedules OWNER TO marali_sante_user;

--
-- Name: booking_schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.booking_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.booking_schedules_id_seq OWNER TO marali_sante_user;

--
-- Name: booking_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.booking_schedules_id_seq OWNED BY public.booking_schedules.id;


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.bookings (
    id bigint NOT NULL,
    customer_id integer,
    user_id integer,
    booking_number character varying,
    booking_date timestamp(6) without time zone,
    status character varying,
    payment_method character varying,
    payment_status character varying,
    subtotal numeric,
    tax_amount numeric,
    discount_amount numeric,
    total_amount numeric,
    notes text,
    booking_items text,
    customer_name character varying,
    customer_email character varying,
    customer_phone character varying,
    delivery_address text,
    invoice_generated boolean,
    invoice_number character varying,
    cash_received numeric,
    change_amount numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    booking_schedule_id bigint,
    stage character varying,
    courier_service character varying,
    tracking_number character varying,
    shipping_charges numeric(10,2),
    expected_delivery_date date,
    delivery_person character varying,
    delivery_contact character varying,
    delivered_to character varying,
    delivery_time timestamp(6) without time zone,
    customer_satisfaction integer,
    processing_team character varying,
    expected_completion_time timestamp(6) without time zone,
    estimated_processing_time character varying,
    estimated_delivery_time character varying,
    package_weight numeric(8,2),
    package_dimensions character varying,
    quality_status character varying,
    cancellation_reason character varying,
    return_reason character varying,
    return_condition character varying,
    refund_amount numeric(10,2),
    refund_method character varying,
    transition_notes text,
    stage_history text,
    stage_updated_at timestamp(6) without time zone,
    stage_updated_by integer,
    store_id bigint,
    subscription_id integer,
    is_subscription boolean,
    final_amount_after_discount numeric,
    delivery_person_id bigint,
    franchise_id bigint,
    quick_invoice boolean DEFAULT false,
    booked_by character varying DEFAULT 'admin'::character varying,
    selected_shop_address text,
    delivery_store text,
    cashfree_order_id character varying,
    payment_session_id character varying,
    cashfree_payment_id character varying,
    gateway_response text,
    payment_gateway character varying DEFAULT 'cash'::character varying,
    payment_initiated_at timestamp(6) without time zone,
    payment_completed_at timestamp(6) without time zone
);


ALTER TABLE public.bookings OWNER TO marali_sante_user;

--
-- Name: bookings_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.bookings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bookings_id_seq OWNER TO marali_sante_user;

--
-- Name: bookings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.bookings_id_seq OWNED BY public.bookings.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    image character varying,
    status boolean DEFAULT true,
    display_order integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    image_backup_url character varying
);


ALTER TABLE public.categories OWNER TO marali_sante_user;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categories_id_seq OWNER TO marali_sante_user;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: client_requests; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.client_requests (
    id bigint NOT NULL,
    title character varying,
    description text,
    status character varying DEFAULT 'pending'::character varying,
    priority character varying DEFAULT 'medium'::character varying,
    customer_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    stage character varying DEFAULT 'new'::character varying,
    stage_updated_at timestamp(6) without time zone,
    stage_history text,
    assignee_id integer,
    department character varying,
    estimated_resolution_time timestamp(6) without time zone,
    actual_resolution_time timestamp(6) without time zone,
    name character varying,
    email character varying,
    phone_number character varying,
    ticket_number character varying,
    admin_response text,
    resolved_by_id integer,
    submitted_at timestamp(6) without time zone,
    resolved_at timestamp(6) without time zone
);


ALTER TABLE public.client_requests OWNER TO marali_sante_user;

--
-- Name: client_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.client_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.client_requests_id_seq OWNER TO marali_sante_user;

--
-- Name: client_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.client_requests_id_seq OWNED BY public.client_requests.id;


--
-- Name: coupons; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.coupons (
    id bigint NOT NULL,
    code character varying,
    description text,
    discount_type character varying,
    discount_value numeric,
    minimum_amount numeric,
    maximum_discount numeric,
    usage_limit integer,
    used_count integer,
    valid_from timestamp(6) without time zone,
    valid_until timestamp(6) without time zone,
    status boolean,
    applicable_products text,
    applicable_categories text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.coupons OWNER TO marali_sante_user;

--
-- Name: coupons_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.coupons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.coupons_id_seq OWNER TO marali_sante_user;

--
-- Name: coupons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.coupons_id_seq OWNED BY public.coupons.id;


--
-- Name: customer_addresses; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.customer_addresses (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    name character varying,
    mobile character varying,
    address_type character varying,
    address text,
    landmark character varying,
    city character varying,
    state character varying,
    pincode character varying,
    latitude numeric,
    longitude numeric,
    is_default boolean,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.customer_addresses OWNER TO marali_sante_user;

--
-- Name: customer_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.customer_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customer_addresses_id_seq OWNER TO marali_sante_user;

--
-- Name: customer_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.customer_addresses_id_seq OWNED BY public.customer_addresses.id;


--
-- Name: customer_formats; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.customer_formats (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    pattern character varying,
    quantity numeric,
    product_id bigint NOT NULL,
    delivery_person_id bigint NOT NULL,
    status character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    days text
);


ALTER TABLE public.customer_formats OWNER TO marali_sante_user;

--
-- Name: customer_formats_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.customer_formats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customer_formats_id_seq OWNER TO marali_sante_user;

--
-- Name: customer_formats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.customer_formats_id_seq OWNED BY public.customer_formats.id;


--
-- Name: customer_wallets; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.customer_wallets (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    balance numeric(10,2) DEFAULT 0.0,
    status boolean DEFAULT true,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.customer_wallets OWNER TO marali_sante_user;

--
-- Name: customer_wallets_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.customer_wallets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customer_wallets_id_seq OWNER TO marali_sante_user;

--
-- Name: customer_wallets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.customer_wallets_id_seq OWNED BY public.customer_wallets.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.customers (
    id bigint NOT NULL,
    first_name character varying,
    last_name character varying,
    email character varying,
    mobile character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    longitude numeric(10,8),
    latitude numeric(10,8),
    whatsapp_number character varying,
    auto_generated_password character varying,
    location_obtained_at timestamp(6) without time zone,
    location_accuracy numeric(8,2),
    password_digest character varying,
    middle_name character varying,
    address text,
    birth_date date,
    gender character varying,
    marital_status character varying,
    pan_no character varying,
    gst_no character varying,
    company_name character varying,
    occupation character varying,
    annual_income numeric,
    emergency_contact_name character varying,
    emergency_contact_number character varying,
    blood_group character varying,
    nationality character varying,
    preferred_language character varying,
    notes text,
    status boolean DEFAULT true NOT NULL,
    is_registered_by_mobile boolean,
    password_reset_token character varying,
    password_reset_sent_at timestamp(6) without time zone
);


ALTER TABLE public.customers OWNER TO marali_sante_user;

--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_id_seq OWNER TO marali_sante_user;

--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: delivery_people; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.delivery_people (
    id bigint NOT NULL,
    first_name character varying,
    last_name character varying,
    email character varying,
    mobile character varying,
    vehicle_type character varying,
    vehicle_number character varying,
    license_number character varying,
    address text,
    city character varying,
    state character varying,
    pincode character varying,
    emergency_contact_name character varying,
    emergency_contact_mobile character varying,
    joining_date date,
    salary numeric,
    status boolean,
    profile_picture character varying,
    bank_name character varying,
    account_no character varying,
    ifsc_code character varying,
    account_holder_name character varying,
    delivery_areas text,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    password_digest character varying,
    auto_generated_password character varying
);


ALTER TABLE public.delivery_people OWNER TO marali_sante_user;

--
-- Name: delivery_people_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.delivery_people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.delivery_people_id_seq OWNER TO marali_sante_user;

--
-- Name: delivery_people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.delivery_people_id_seq OWNED BY public.delivery_people.id;


--
-- Name: delivery_rules; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.delivery_rules (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    rule_type character varying NOT NULL,
    location_data text,
    is_excluded boolean DEFAULT false,
    delivery_days integer,
    delivery_charge numeric(8,2) DEFAULT 0.0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.delivery_rules OWNER TO marali_sante_user;

--
-- Name: delivery_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.delivery_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.delivery_rules_id_seq OWNER TO marali_sante_user;

--
-- Name: delivery_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.delivery_rules_id_seq OWNED BY public.delivery_rules.id;


--
-- Name: device_tokens; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.device_tokens (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    delivery_person_id bigint NOT NULL,
    token character varying,
    device_type character varying,
    active boolean,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.device_tokens OWNER TO marali_sante_user;

--
-- Name: device_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.device_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.device_tokens_id_seq OWNER TO marali_sante_user;

--
-- Name: device_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.device_tokens_id_seq OWNED BY public.device_tokens.id;


--
-- Name: franchises; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.franchises (
    id bigint NOT NULL,
    name character varying,
    email character varying,
    mobile character varying,
    contact_person_name character varying,
    business_type character varying,
    address text,
    city character varying,
    state character varying,
    pincode character varying,
    pan_no character varying,
    gst_no character varying,
    license_no character varying,
    establishment_date date,
    territory character varying,
    franchise_fee numeric,
    commission_percentage numeric,
    status boolean,
    notes text,
    password_digest character varying,
    auto_generated_password character varying,
    longitude numeric,
    latitude numeric,
    whatsapp_number character varying,
    profile_image character varying,
    business_documents text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint
);


ALTER TABLE public.franchises OWNER TO marali_sante_user;

--
-- Name: franchises_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.franchises_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.franchises_id_seq OWNER TO marali_sante_user;

--
-- Name: franchises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.franchises_id_seq OWNED BY public.franchises.id;


--
-- Name: invoice_items; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.invoice_items (
    id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    milk_delivery_task_id bigint,
    description text,
    quantity numeric,
    unit_price numeric,
    total_amount numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    product_id bigint
);


ALTER TABLE public.invoice_items OWNER TO marali_sante_user;

--
-- Name: invoice_items_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.invoice_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_items_id_seq OWNER TO marali_sante_user;

--
-- Name: invoice_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.invoice_items_id_seq OWNED BY public.invoice_items.id;


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.invoices (
    id bigint NOT NULL,
    invoice_number character varying,
    payout_type character varying,
    payout_id integer,
    total_amount numeric,
    status character varying,
    invoice_date date,
    due_date date,
    paid_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    customer_id integer,
    payment_status integer,
    share_token character varying,
    quick_invoice boolean DEFAULT false,
    paid_amount numeric(10,2) DEFAULT 0.0
);


ALTER TABLE public.invoices OWNER TO marali_sante_user;

--
-- Name: invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.invoices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoices_id_seq OWNER TO marali_sante_user;

--
-- Name: invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.invoices_id_seq OWNED BY public.invoices.id;


--
-- Name: leads; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.leads (
    id bigint NOT NULL,
    name character varying,
    contact_number character varying,
    email character varying,
    current_stage character varying,
    lead_source character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    product_category character varying,
    product_subcategory character varying,
    customer_type character varying,
    affiliate_id integer,
    is_direct boolean,
    first_name character varying,
    last_name character varying,
    middle_name character varying,
    company_name character varying,
    gender character varying,
    marital_status character varying,
    pan_no character varying,
    gst_no character varying,
    height numeric,
    weight numeric,
    annual_income numeric,
    business_job character varying
);


ALTER TABLE public.leads OWNER TO marali_sante_user;

--
-- Name: leads_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.leads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.leads_id_seq OWNER TO marali_sante_user;

--
-- Name: leads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.leads_id_seq OWNED BY public.leads.id;


--
-- Name: milk_delivery_tasks; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.milk_delivery_tasks (
    id bigint NOT NULL,
    subscription_id bigint,
    customer_id bigint NOT NULL,
    product_id bigint NOT NULL,
    quantity numeric(10,2),
    unit character varying,
    delivery_date date,
    delivery_person_id bigint,
    status character varying DEFAULT 'pending'::character varying,
    assigned_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    delivery_notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    invoiced boolean DEFAULT false,
    invoiced_at timestamp(6) without time zone
);


ALTER TABLE public.milk_delivery_tasks OWNER TO marali_sante_user;

--
-- Name: milk_delivery_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.milk_delivery_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.milk_delivery_tasks_id_seq OWNER TO marali_sante_user;

--
-- Name: milk_delivery_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.milk_delivery_tasks_id_seq OWNED BY public.milk_delivery_tasks.id;


--
-- Name: milk_subscriptions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.milk_subscriptions (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    product_id bigint NOT NULL,
    quantity numeric(10,2),
    unit character varying DEFAULT 'liter'::character varying,
    start_date date,
    end_date date,
    delivery_time character varying DEFAULT 'morning'::character varying,
    delivery_pattern character varying DEFAULT 'daily'::character varying,
    specific_dates text,
    total_amount numeric(10,2),
    status character varying DEFAULT 'active'::character varying,
    is_active boolean DEFAULT true,
    created_by integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    delivery_person_id integer
);


ALTER TABLE public.milk_subscriptions OWNER TO marali_sante_user;

--
-- Name: milk_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.milk_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.milk_subscriptions_id_seq OWNER TO marali_sante_user;

--
-- Name: milk_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.milk_subscriptions_id_seq OWNED BY public.milk_subscriptions.id;


--
-- Name: notes; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.notes (
    id bigint NOT NULL,
    title character varying NOT NULL,
    paid_to character varying NOT NULL,
    amount numeric(10,2) NOT NULL,
    payment_method character varying NOT NULL,
    reference_number character varying,
    description text,
    status character varying DEFAULT 'pending'::character varying,
    note_date date DEFAULT CURRENT_DATE NOT NULL,
    created_by_user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    paid_from character varying,
    paid_to_category character varying
);


ALTER TABLE public.notes OWNER TO marali_sante_user;

--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notes_id_seq OWNER TO marali_sante_user;

--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.notes_id_seq OWNED BY public.notes.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    title character varying,
    message text,
    notification_type character varying,
    data json,
    read boolean,
    read_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.notifications OWNER TO marali_sante_user;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_id_seq OWNER TO marali_sante_user;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id integer,
    product_id integer,
    quantity integer,
    price numeric,
    total numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.order_items OWNER TO marali_sante_user;

--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_id_seq OWNER TO marali_sante_user;

--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    customer_id integer,
    user_id integer,
    order_number character varying,
    order_date timestamp(6) without time zone,
    status character varying,
    payment_method character varying,
    payment_status character varying,
    subtotal numeric,
    tax_amount numeric,
    discount_amount numeric,
    shipping_amount numeric,
    total_amount numeric,
    notes text,
    order_items text,
    customer_name character varying,
    customer_email character varying,
    customer_phone character varying,
    delivery_address text,
    tracking_number character varying,
    delivered_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    processing_notes text,
    estimated_processing_time integer,
    processing_started_at timestamp(6) without time zone,
    packed_by character varying,
    package_weight numeric,
    package_dimensions character varying,
    packing_notes text,
    packed_at timestamp(6) without time zone,
    shipping_carrier character varying,
    estimated_delivery_date date,
    shipping_cost numeric,
    shipping_notes text,
    shipped_at timestamp(6) without time zone,
    delivered_to character varying,
    delivery_location character varying,
    delivery_notes text,
    cancelled_at timestamp(6) without time zone,
    cancellation_reason character varying,
    refund_method character varying,
    refund_amount numeric,
    cancellation_notes text,
    invoice_generated boolean DEFAULT false,
    invoice_number character varying,
    cash_received numeric(10,2),
    change_amount numeric(10,2),
    order_stage character varying DEFAULT 'draft'::character varying,
    booking_date timestamp(6) without time zone,
    booking_id integer
);


ALTER TABLE public.orders OWNER TO marali_sante_user;

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_id_seq OWNER TO marali_sante_user;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: pending_amounts; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.pending_amounts (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    amount numeric,
    description text,
    pending_date date,
    status integer,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.pending_amounts OWNER TO marali_sante_user;

--
-- Name: pending_amounts_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.pending_amounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pending_amounts_id_seq OWNER TO marali_sante_user;

--
-- Name: pending_amounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.pending_amounts_id_seq OWNED BY public.pending_amounts.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.permissions (
    id bigint NOT NULL,
    name character varying NOT NULL,
    resource character varying,
    action character varying,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.permissions OWNER TO marali_sante_user;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.permissions_id_seq OWNER TO marali_sante_user;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: product_ratings; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.product_ratings (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    customer_id bigint,
    user_id bigint,
    rating integer NOT NULL,
    comment text,
    status integer DEFAULT 0,
    reviewer_name character varying,
    reviewer_email character varying,
    verified_purchase boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.product_ratings OWNER TO marali_sante_user;

--
-- Name: product_ratings_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.product_ratings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_ratings_id_seq OWNER TO marali_sante_user;

--
-- Name: product_ratings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.product_ratings_id_seq OWNED BY public.product_ratings.id;


--
-- Name: product_reviews; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.product_reviews (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    customer_id bigint,
    user_id bigint,
    rating integer NOT NULL,
    comment text,
    reviewer_name character varying,
    reviewer_email character varying,
    status integer DEFAULT 0,
    verified_purchase boolean DEFAULT false,
    helpful_count integer DEFAULT 0,
    pros text,
    cons text,
    title character varying,
    images_data json,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.product_reviews OWNER TO marali_sante_user;

--
-- Name: product_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.product_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_reviews_id_seq OWNER TO marali_sante_user;

--
-- Name: product_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.product_reviews_id_seq OWNED BY public.product_reviews.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.products (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    category_id bigint NOT NULL,
    price numeric(10,2) NOT NULL,
    discount_price numeric(10,2),
    stock integer DEFAULT 0,
    status character varying DEFAULT 'active'::character varying,
    sku character varying NOT NULL,
    weight numeric(8,3),
    dimensions character varying,
    meta_title text,
    meta_description text,
    tags text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    discount_type character varying,
    discount_value numeric(10,2),
    original_price numeric(10,2),
    discount_amount numeric(10,2),
    is_discounted boolean DEFAULT false,
    gst_enabled boolean DEFAULT false,
    gst_percentage numeric(5,2),
    cgst_percentage numeric(5,2),
    sgst_percentage numeric(5,2),
    igst_percentage numeric(5,2),
    gst_amount numeric(10,2),
    cgst_amount numeric(10,2),
    sgst_amount numeric(10,2),
    igst_amount numeric(10,2),
    final_amount_with_gst numeric(10,2),
    buying_price numeric(10,2),
    yesterday_price numeric(10,2),
    today_price numeric(10,2),
    price_change_percentage numeric(5,2),
    last_price_update timestamp(6) without time zone,
    price_history text,
    is_occasional_product boolean DEFAULT false NOT NULL,
    occasional_start_date timestamp(6) without time zone,
    occasional_end_date timestamp(6) without time zone,
    occasional_description text,
    occasional_auto_hide boolean DEFAULT true NOT NULL,
    product_type character varying DEFAULT 'Grocery'::character varying,
    occasional_schedule_type character varying,
    occasional_recurring_from_day character varying,
    occasional_recurring_from_time time without time zone,
    occasional_recurring_to_day character varying,
    occasional_recurring_to_time time without time zone,
    is_subscription_enabled boolean DEFAULT false,
    unit_type character varying,
    minimum_stock_alert integer,
    default_selling_price numeric,
    hsn_code character varying,
    image_url character varying,
    additional_images_urls text,
    display_order integer,
    base_price_excluding_gst numeric,
    r2_image_url character varying,
    r2_additional_images text
);


ALTER TABLE public.products OWNER TO marali_sante_user;

--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_id_seq OWNER TO marali_sante_user;

--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: referrals; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.referrals (
    id bigint NOT NULL,
    affiliate_id bigint,
    referred_name character varying,
    referred_mobile character varying,
    referred_email character varying,
    referral_date date,
    status character varying,
    notes text,
    converted_at timestamp(6) without time zone,
    customer_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    referring_customer_id bigint,
    referral_source character varying DEFAULT 'affiliate'::character varying
);


ALTER TABLE public.referrals OWNER TO marali_sante_user;

--
-- Name: referrals_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.referrals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.referrals_id_seq OWNER TO marali_sante_user;

--
-- Name: referrals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.referrals_id_seq OWNED BY public.referrals.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    name character varying,
    description text,
    status boolean,
    permissions text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.roles OWNER TO marali_sante_user;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roles_id_seq OWNER TO marali_sante_user;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: sale_items; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.sale_items (
    id bigint NOT NULL,
    booking_id bigint NOT NULL,
    product_id bigint NOT NULL,
    stock_batch_id bigint NOT NULL,
    quantity numeric,
    selling_price numeric,
    purchase_price numeric,
    profit_amount numeric,
    line_total numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.sale_items OWNER TO marali_sante_user;

--
-- Name: sale_items_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.sale_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sale_items_id_seq OWNER TO marali_sante_user;

--
-- Name: sale_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.sale_items_id_seq OWNED BY public.sale_items.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO marali_sante_user;

--
-- Name: solid_cache_entries; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_cache_entries (
    id bigint NOT NULL,
    key bytea NOT NULL,
    value bytea NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key_hash bigint NOT NULL,
    byte_size integer NOT NULL
);


ALTER TABLE public.solid_cache_entries OWNER TO marali_sante_user;

--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_cache_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_cache_entries_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_cache_entries_id_seq OWNED BY public.solid_cache_entries.id;


--
-- Name: solid_queue_blocked_executions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_blocked_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    concurrency_key character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_blocked_executions OWNER TO marali_sante_user;

--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_blocked_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_blocked_executions_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_blocked_executions_id_seq OWNED BY public.solid_queue_blocked_executions.id;


--
-- Name: solid_queue_claimed_executions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_claimed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    process_id bigint,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_claimed_executions OWNER TO marali_sante_user;

--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_claimed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_claimed_executions_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_claimed_executions_id_seq OWNED BY public.solid_queue_claimed_executions.id;


--
-- Name: solid_queue_failed_executions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_failed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    error text,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_failed_executions OWNER TO marali_sante_user;

--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_failed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_failed_executions_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_failed_executions_id_seq OWNED BY public.solid_queue_failed_executions.id;


--
-- Name: solid_queue_jobs; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_jobs (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    class_name character varying NOT NULL,
    arguments text,
    priority integer DEFAULT 0 NOT NULL,
    active_job_id character varying,
    scheduled_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    concurrency_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_jobs OWNER TO marali_sante_user;

--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_jobs_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_jobs_id_seq OWNED BY public.solid_queue_jobs.id;


--
-- Name: solid_queue_pauses; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_pauses (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_pauses OWNER TO marali_sante_user;

--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_pauses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_pauses_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_pauses_id_seq OWNED BY public.solid_queue_pauses.id;


--
-- Name: solid_queue_processes; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_processes (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    last_heartbeat_at timestamp(6) without time zone NOT NULL,
    supervisor_id bigint,
    pid integer NOT NULL,
    hostname character varying,
    metadata text,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.solid_queue_processes OWNER TO marali_sante_user;

--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_processes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_processes_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_processes_id_seq OWNED BY public.solid_queue_processes.id;


--
-- Name: solid_queue_ready_executions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_ready_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_ready_executions OWNER TO marali_sante_user;

--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_ready_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_ready_executions_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_ready_executions_id_seq OWNED BY public.solid_queue_ready_executions.id;


--
-- Name: solid_queue_recurring_executions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_recurring_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    task_key character varying NOT NULL,
    run_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_recurring_executions OWNER TO marali_sante_user;

--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_recurring_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_recurring_executions_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_recurring_executions_id_seq OWNED BY public.solid_queue_recurring_executions.id;


--
-- Name: solid_queue_recurring_tasks; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_recurring_tasks (
    id bigint NOT NULL,
    key character varying NOT NULL,
    schedule character varying NOT NULL,
    command character varying(2048),
    class_name character varying,
    arguments text,
    queue_name character varying,
    priority integer DEFAULT 0,
    static boolean DEFAULT true NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_recurring_tasks OWNER TO marali_sante_user;

--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_recurring_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_recurring_tasks_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_recurring_tasks_id_seq OWNED BY public.solid_queue_recurring_tasks.id;


--
-- Name: solid_queue_scheduled_executions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_scheduled_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    scheduled_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_scheduled_executions OWNER TO marali_sante_user;

--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_scheduled_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_scheduled_executions_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_scheduled_executions_id_seq OWNED BY public.solid_queue_scheduled_executions.id;


--
-- Name: solid_queue_semaphores; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.solid_queue_semaphores (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value integer DEFAULT 1 NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.solid_queue_semaphores OWNER TO marali_sante_user;

--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.solid_queue_semaphores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solid_queue_semaphores_id_seq OWNER TO marali_sante_user;

--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.solid_queue_semaphores_id_seq OWNED BY public.solid_queue_semaphores.id;


--
-- Name: stock_batches; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.stock_batches (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    vendor_purchase_id bigint,
    quantity_purchased numeric,
    quantity_remaining numeric,
    purchase_price numeric,
    selling_price numeric,
    batch_date date,
    status character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.stock_batches OWNER TO marali_sante_user;

--
-- Name: stock_batches_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.stock_batches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stock_batches_id_seq OWNER TO marali_sante_user;

--
-- Name: stock_batches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.stock_batches_id_seq OWNED BY public.stock_batches.id;


--
-- Name: stock_movements; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.stock_movements (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    reference_type character varying NOT NULL,
    reference_id integer,
    movement_type character varying NOT NULL,
    quantity numeric(10,2) NOT NULL,
    stock_before numeric(10,2) NOT NULL,
    stock_after numeric(10,2) NOT NULL,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.stock_movements OWNER TO marali_sante_user;

--
-- Name: stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.stock_movements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stock_movements_id_seq OWNER TO marali_sante_user;

--
-- Name: stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.stock_movements_id_seq OWNED BY public.stock_movements.id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.stores (
    id bigint NOT NULL,
    name character varying,
    description text,
    address text,
    city character varying,
    state character varying,
    pincode character varying,
    contact_person character varying,
    contact_mobile character varying,
    email character varying,
    status boolean,
    gst_no character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.stores OWNER TO marali_sante_user;

--
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stores_id_seq OWNER TO marali_sante_user;

--
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.stores_id_seq OWNED BY public.stores.id;


--
-- Name: sub_agents; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.sub_agents (
    id bigint NOT NULL,
    first_name character varying,
    last_name character varying,
    middle_name character varying,
    email character varying,
    mobile character varying,
    password_digest character varying,
    plain_password character varying,
    original_password character varying,
    role_id integer,
    gender character varying,
    birth_date date,
    pan_no character varying,
    aadhar_no character varying,
    gst_no character varying,
    company_name character varying,
    address text,
    city character varying,
    state character varying,
    pincode character varying,
    country character varying,
    profile_picture character varying,
    bank_name character varying,
    account_no character varying,
    ifsc_code character varying,
    account_holder_name character varying,
    account_type character varying,
    upi_id character varying,
    emergency_contact_name character varying,
    emergency_contact_mobile character varying,
    joining_date date,
    salary numeric(10,2),
    notes text,
    status integer DEFAULT 0,
    distributor_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.sub_agents OWNER TO marali_sante_user;

--
-- Name: sub_agents_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.sub_agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sub_agents_id_seq OWNER TO marali_sante_user;

--
-- Name: sub_agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.sub_agents_id_seq OWNED BY public.sub_agents.id;


--
-- Name: subscription_templates; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.subscription_templates (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    product_id bigint NOT NULL,
    delivery_person_id bigint,
    quantity numeric(8,2),
    unit character varying,
    price numeric(10,2),
    delivery_time character varying,
    is_active boolean,
    template_name character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.subscription_templates OWNER TO marali_sante_user;

--
-- Name: subscription_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.subscription_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.subscription_templates_id_seq OWNER TO marali_sante_user;

--
-- Name: subscription_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.subscription_templates_id_seq OWNED BY public.subscription_templates.id;


--
-- Name: system_settings; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.system_settings (
    id bigint NOT NULL,
    key character varying,
    value text,
    setting_type character varying,
    description text,
    default_main_agent_commission numeric,
    default_affiliate_commission numeric,
    default_ambassador_commission numeric,
    default_company_expenses numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    business_name character varying,
    address text,
    mobile character varying,
    email character varying,
    gstin character varying,
    pan_number character varying,
    account_holder_name character varying,
    bank_name character varying,
    account_number character varying,
    ifsc_code character varying,
    upi_id character varying,
    qr_code_path character varying,
    terms_and_conditions text,
    collect_from_store_enabled boolean,
    delivery_only_at_shop boolean,
    shop_addresses text
);


ALTER TABLE public.system_settings OWNER TO marali_sante_user;

--
-- Name: system_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.system_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_settings_id_seq OWNER TO marali_sante_user;

--
-- Name: system_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.system_settings_id_seq OWNED BY public.system_settings.id;


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.user_roles (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    active boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.user_roles OWNER TO marali_sante_user;

--
-- Name: user_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.user_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_roles_id_seq OWNER TO marali_sante_user;

--
-- Name: user_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.user_roles_id_seq OWNED BY public.user_roles.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    email character varying NOT NULL,
    mobile character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    middle_name character varying,
    encrypted_password character varying,
    user_type character varying DEFAULT 'admin'::character varying,
    role character varying DEFAULT 'super_admin'::character varying,
    role_id integer,
    status boolean DEFAULT true,
    is_active boolean DEFAULT true,
    is_verified boolean DEFAULT false,
    birth_date date,
    gender character varying,
    pan_no character varying,
    aadhar_no character varying,
    gst_no character varying,
    company_name character varying,
    address text,
    city character varying,
    state character varying,
    pincode character varying,
    country character varying DEFAULT 'India'::character varying,
    profile_picture character varying,
    bank_name character varying,
    account_no character varying,
    ifsc_code character varying,
    account_holder_name character varying,
    account_type character varying,
    upi_id character varying,
    emergency_contact_name character varying,
    emergency_contact_mobile character varying,
    department character varying,
    designation character varying,
    joining_date date,
    salary numeric(10,2),
    employee_id character varying,
    reporting_manager_id integer,
    permissions text,
    sidebar_permissions text,
    last_login_at timestamp(6) without time zone,
    login_count integer DEFAULT 0,
    email_verified_at timestamp(6) without time zone,
    mobile_verified_at timestamp(6) without time zone,
    two_factor_enabled boolean DEFAULT false,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    sign_in_count integer DEFAULT 0,
    current_sign_in_at timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    confirmation_token character varying,
    confirmed_at timestamp(6) without time zone,
    confirmation_sent_at timestamp(6) without time zone,
    unlock_token character varying,
    locked_at timestamp(6) without time zone,
    failed_attempts integer DEFAULT 0,
    notes text,
    created_by integer,
    updated_by integer,
    deleted_at timestamp(6) without time zone,
    original_password character varying,
    authenticatable_type character varying,
    authenticatable_id bigint
);


ALTER TABLE public.users OWNER TO marali_sante_user;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO marali_sante_user;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: vendor_invoices; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.vendor_invoices (
    id bigint NOT NULL,
    vendor_purchase_id bigint NOT NULL,
    invoice_number character varying,
    total_amount numeric,
    status integer,
    invoice_date date,
    share_token character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.vendor_invoices OWNER TO marali_sante_user;

--
-- Name: vendor_invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.vendor_invoices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vendor_invoices_id_seq OWNER TO marali_sante_user;

--
-- Name: vendor_invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.vendor_invoices_id_seq OWNED BY public.vendor_invoices.id;


--
-- Name: vendor_payments; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.vendor_payments (
    id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    vendor_purchase_id bigint NOT NULL,
    amount_paid numeric,
    payment_date date,
    payment_mode character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.vendor_payments OWNER TO marali_sante_user;

--
-- Name: vendor_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.vendor_payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vendor_payments_id_seq OWNER TO marali_sante_user;

--
-- Name: vendor_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.vendor_payments_id_seq OWNED BY public.vendor_payments.id;


--
-- Name: vendor_purchase_items; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.vendor_purchase_items (
    id bigint NOT NULL,
    vendor_purchase_id bigint NOT NULL,
    product_id bigint NOT NULL,
    quantity numeric,
    purchase_price numeric,
    selling_price numeric,
    line_total numeric,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.vendor_purchase_items OWNER TO marali_sante_user;

--
-- Name: vendor_purchase_items_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.vendor_purchase_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vendor_purchase_items_id_seq OWNER TO marali_sante_user;

--
-- Name: vendor_purchase_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.vendor_purchase_items_id_seq OWNED BY public.vendor_purchase_items.id;


--
-- Name: vendor_purchases; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.vendor_purchases (
    id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    purchase_date date,
    total_amount numeric,
    paid_amount numeric,
    status character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.vendor_purchases OWNER TO marali_sante_user;

--
-- Name: vendor_purchases_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.vendor_purchases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vendor_purchases_id_seq OWNER TO marali_sante_user;

--
-- Name: vendor_purchases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.vendor_purchases_id_seq OWNED BY public.vendor_purchases.id;


--
-- Name: vendors; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.vendors (
    id bigint NOT NULL,
    name character varying,
    phone character varying,
    email character varying,
    address text,
    payment_type character varying,
    opening_balance numeric,
    status boolean,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.vendors OWNER TO marali_sante_user;

--
-- Name: vendors_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.vendors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vendors_id_seq OWNER TO marali_sante_user;

--
-- Name: vendors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.vendors_id_seq OWNED BY public.vendors.id;


--
-- Name: wallet_transactions; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.wallet_transactions (
    id bigint NOT NULL,
    customer_wallet_id bigint NOT NULL,
    transaction_type character varying,
    amount numeric(10,2),
    balance_after numeric(10,2),
    description character varying,
    reference_number character varying,
    metadata json,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.wallet_transactions OWNER TO marali_sante_user;

--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.wallet_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.wallet_transactions_id_seq OWNER TO marali_sante_user;

--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.wallet_transactions_id_seq OWNED BY public.wallet_transactions.id;


--
-- Name: wishlists; Type: TABLE; Schema: public; Owner: marali_sante_user
--

CREATE TABLE public.wishlists (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    product_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.wishlists OWNER TO marali_sante_user;

--
-- Name: wishlists_id_seq; Type: SEQUENCE; Schema: public; Owner: marali_sante_user
--

CREATE SEQUENCE public.wishlists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.wishlists_id_seq OWNER TO marali_sante_user;

--
-- Name: wishlists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: marali_sante_user
--

ALTER SEQUENCE public.wishlists_id_seq OWNED BY public.wishlists.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: affiliates id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.affiliates ALTER COLUMN id SET DEFAULT nextval('public.affiliates_id_seq'::regclass);


--
-- Name: banners id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.banners ALTER COLUMN id SET DEFAULT nextval('public.banners_id_seq'::regclass);


--
-- Name: booking_invoices id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_invoices ALTER COLUMN id SET DEFAULT nextval('public.booking_invoices_id_seq'::regclass);


--
-- Name: booking_items id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_items ALTER COLUMN id SET DEFAULT nextval('public.booking_items_id_seq'::regclass);


--
-- Name: booking_schedules id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_schedules ALTER COLUMN id SET DEFAULT nextval('public.booking_schedules_id_seq'::regclass);


--
-- Name: bookings id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.bookings ALTER COLUMN id SET DEFAULT nextval('public.bookings_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: client_requests id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.client_requests ALTER COLUMN id SET DEFAULT nextval('public.client_requests_id_seq'::regclass);


--
-- Name: coupons id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.coupons ALTER COLUMN id SET DEFAULT nextval('public.coupons_id_seq'::regclass);


--
-- Name: customer_addresses id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_addresses ALTER COLUMN id SET DEFAULT nextval('public.customer_addresses_id_seq'::regclass);


--
-- Name: customer_formats id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_formats ALTER COLUMN id SET DEFAULT nextval('public.customer_formats_id_seq'::regclass);


--
-- Name: customer_wallets id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_wallets ALTER COLUMN id SET DEFAULT nextval('public.customer_wallets_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: delivery_people id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.delivery_people ALTER COLUMN id SET DEFAULT nextval('public.delivery_people_id_seq'::regclass);


--
-- Name: delivery_rules id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.delivery_rules ALTER COLUMN id SET DEFAULT nextval('public.delivery_rules_id_seq'::regclass);


--
-- Name: device_tokens id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.device_tokens ALTER COLUMN id SET DEFAULT nextval('public.device_tokens_id_seq'::regclass);


--
-- Name: franchises id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.franchises ALTER COLUMN id SET DEFAULT nextval('public.franchises_id_seq'::regclass);


--
-- Name: invoice_items id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.invoice_items ALTER COLUMN id SET DEFAULT nextval('public.invoice_items_id_seq'::regclass);


--
-- Name: invoices id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.invoices ALTER COLUMN id SET DEFAULT nextval('public.invoices_id_seq'::regclass);


--
-- Name: leads id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.leads ALTER COLUMN id SET DEFAULT nextval('public.leads_id_seq'::regclass);


--
-- Name: milk_delivery_tasks id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_delivery_tasks ALTER COLUMN id SET DEFAULT nextval('public.milk_delivery_tasks_id_seq'::regclass);


--
-- Name: milk_subscriptions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.milk_subscriptions_id_seq'::regclass);


--
-- Name: notes id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.notes ALTER COLUMN id SET DEFAULT nextval('public.notes_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: pending_amounts id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.pending_amounts ALTER COLUMN id SET DEFAULT nextval('public.pending_amounts_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: product_ratings id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_ratings ALTER COLUMN id SET DEFAULT nextval('public.product_ratings_id_seq'::regclass);


--
-- Name: product_reviews id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_reviews ALTER COLUMN id SET DEFAULT nextval('public.product_reviews_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: referrals id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.referrals ALTER COLUMN id SET DEFAULT nextval('public.referrals_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: sale_items id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.sale_items ALTER COLUMN id SET DEFAULT nextval('public.sale_items_id_seq'::regclass);


--
-- Name: solid_cache_entries id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_cache_entries ALTER COLUMN id SET DEFAULT nextval('public.solid_cache_entries_id_seq'::regclass);


--
-- Name: solid_queue_blocked_executions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_blocked_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_blocked_executions_id_seq'::regclass);


--
-- Name: solid_queue_claimed_executions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_claimed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_claimed_executions_id_seq'::regclass);


--
-- Name: solid_queue_failed_executions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_failed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_failed_executions_id_seq'::regclass);


--
-- Name: solid_queue_jobs id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_jobs ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_jobs_id_seq'::regclass);


--
-- Name: solid_queue_pauses id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_pauses ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_pauses_id_seq'::regclass);


--
-- Name: solid_queue_processes id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_processes ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_processes_id_seq'::regclass);


--
-- Name: solid_queue_ready_executions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_ready_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_ready_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_executions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_recurring_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_tasks id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_tasks_id_seq'::regclass);


--
-- Name: solid_queue_scheduled_executions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_scheduled_executions_id_seq'::regclass);


--
-- Name: solid_queue_semaphores id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_semaphores ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_semaphores_id_seq'::regclass);


--
-- Name: stock_batches id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stock_batches ALTER COLUMN id SET DEFAULT nextval('public.stock_batches_id_seq'::regclass);


--
-- Name: stock_movements id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stock_movements ALTER COLUMN id SET DEFAULT nextval('public.stock_movements_id_seq'::regclass);


--
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


--
-- Name: sub_agents id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.sub_agents ALTER COLUMN id SET DEFAULT nextval('public.sub_agents_id_seq'::regclass);


--
-- Name: subscription_templates id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.subscription_templates ALTER COLUMN id SET DEFAULT nextval('public.subscription_templates_id_seq'::regclass);


--
-- Name: system_settings id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.system_settings ALTER COLUMN id SET DEFAULT nextval('public.system_settings_id_seq'::regclass);


--
-- Name: user_roles id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.user_roles ALTER COLUMN id SET DEFAULT nextval('public.user_roles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: vendor_invoices id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_invoices ALTER COLUMN id SET DEFAULT nextval('public.vendor_invoices_id_seq'::regclass);


--
-- Name: vendor_payments id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_payments ALTER COLUMN id SET DEFAULT nextval('public.vendor_payments_id_seq'::regclass);


--
-- Name: vendor_purchase_items id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_purchase_items ALTER COLUMN id SET DEFAULT nextval('public.vendor_purchase_items_id_seq'::regclass);


--
-- Name: vendor_purchases id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_purchases ALTER COLUMN id SET DEFAULT nextval('public.vendor_purchases_id_seq'::regclass);


--
-- Name: vendors id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendors ALTER COLUMN id SET DEFAULT nextval('public.vendors_id_seq'::regclass);


--
-- Name: wallet_transactions id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.wallet_transactions ALTER COLUMN id SET DEFAULT nextval('public.wallet_transactions_id_seq'::regclass);


--
-- Name: wishlists id; Type: DEFAULT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.wishlists ALTER COLUMN id SET DEFAULT nextval('public.wishlists_id_seq'::regclass);


--
-- Data for Name: active_storage_attachments; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.active_storage_attachments (id, name, record_type, record_id, blob_id, created_at) FROM stdin;
4	image	Category	2	4	2026-02-12 16:43:18.90868
8	personal_image	Customer	2	8	2026-02-16 11:41:09.107367
9	image	Category	5	9	2026-02-16 15:33:45.176034
10	image	Category	4	10	2026-02-16 15:36:49.145211
11	image	Category	6	11	2026-02-16 15:40:00.723689
12	image	Category	7	12	2026-02-16 15:43:43.084157
13	personal_image	Customer	4	13	2026-02-16 15:57:33.158563
14	images	Product	6	14	2026-02-17 11:36:34.789557
15	image	Category	12	15	2026-02-21 10:11:28.03443
16	image	Category	13	16	2026-02-21 10:13:49.354861
18	personal_image	Customer	20	18	2026-02-21 12:14:15.154785
19	personal_image	Customer	18	19	2026-02-23 12:37:55.947709
20	house_image	Customer	18	20	2026-02-23 12:37:56.446492
21	personal_image	Customer	48	21	2026-02-24 01:34:54.410908
23	banner_image	Banner	3	23	2026-02-24 03:43:45.911136
24	banner_image	Banner	4	24	2026-02-24 03:44:10.868693
25	image	Category	1	25	2026-02-27 00:42:18.108084
26	personal_image	Customer	469	26	2026-03-04 06:38:37.307697
\.


--
-- Data for Name: active_storage_blobs; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.active_storage_blobs (id, key, filename, content_type, metadata, service_name, byte_size, checksum, created_at) FROM stdin;
1	3t1l827fk1vzmzkquysqrq93k0oq	WhatsApp Image 2026-02-08 at 9.25.11 PM.jpeg	image/jpeg	{"identified":true}	local	22400	jl6yRAWPOl8M+oO/pe1gvg==	2026-02-12 11:54:12.716336
2	vhuvvt9jio63b6l39nxht19hbe6q	WhatsApp Image 2026-02-08 at 9.25.11 PM.jpeg	image/jpeg	{"identified":true}	local	22400	jl6yRAWPOl8M+oO/pe1gvg==	2026-02-12 13:21:23.988587
3	ygzl179oghvcnxckt5eocbgvx9j7	personal-care.png	image/png	{"identified":true}	local	4046	VgcfexvxBptpaTwlGk1YWw==	2026-02-12 16:39:33.274898
4	zt1kuuq8l3nf2gnfdpwdmktj1607	personal-care.png	image/png	{"identified":true}	local	4046	VgcfexvxBptpaTwlGk1YWw==	2026-02-12 16:43:18.783373
5	yn1mrxcw3vbldcriiucbl3xz2lhk	personal-care.png	image/png	{"identified":true}	local	4046	VgcfexvxBptpaTwlGk1YWw==	2026-02-12 16:45:24.682986
6	7s74a8nw3674ptsftayje2uuawom	personal-care.png	image/png	{"identified":true}	local	4046	VgcfexvxBptpaTwlGk1YWw==	2026-02-13 05:51:24.593515
7	nvf2nao6idmpl0vymxh2jqc8bxxi	personal-care.png	image/png	{"identified":true}	local	4046	VgcfexvxBptpaTwlGk1YWw==	2026-02-13 05:52:07.312809
8	9f0frgqvpg9cjalc9603r665d04y	WhatsApp Image 2026-02-08 at 9.25.11 PM.jpeg	image/jpeg	{"identified":true}	local	22400	jl6yRAWPOl8M+oO/pe1gvg==	2026-02-16 11:41:08.817681
9	jaz3ubzewvhtn77neu8ruuohq7zz	spices.png	image/png	{"identified":true}	local	45237	dAspij4PHNJoFdsZkn+LiQ==	2026-02-16 15:33:45.020741
10	tc15r646xou5d8flvvg0partcxqu	snacks.jpg	image/jpeg	{"identified":true}	local	34172	bXk3U1YuMI5BDUCkhgHwUA==	2026-02-16 15:36:49.018668
11	dy27b4phyoxwqirnzzltx96z2ziu	nuts.png	image/png	{"identified":true}	local	56205	WGHhqWyZvaux21dOAgXhtQ==	2026-02-16 15:40:00.590984
12	nh3f5gd6ntvfxndap2cvzdlg5wse	whole grain.jpg	image/jpeg	{"identified":true}	local	45428	DWrv7mWMUK7otw++v2Ce/g==	2026-02-16 15:43:42.956899
13	fjh1zqdph598cx6oqfoaiqyqnjhm	WhatsApp Image 2026-02-08 at 9.25.11 PM.jpeg	image/jpeg	{"identified":true}	local	22400	jl6yRAWPOl8M+oO/pe1gvg==	2026-02-16 15:57:33.008874
14	g5azzmt4v6zzy11lxhtrcjqwgw1x	IMG_0417.JPG.jpeg	image/jpeg	{"identified":true}	local	4067876	JvOuBFprbq1CFoPSwNm0YA==	2026-02-17 11:36:34.663576
15	o5voa6yzskkn47k1c5e9wnv3a3um	rice.png	image/png	{"identified":true}	local	5224	y1EouuVyZ5lB/m9hR17N2Q==	2026-02-21 10:11:27.916417
16	a8ux1f3qcf3bsjwg9tv5jykjbgum	vegetables.png	image/png	{"identified":true}	local	41944	vD9QCuNm2jyIwOuaPCY+9g==	2026-02-21 10:13:49.233074
17	nboq1rr17orjjxkjcpo2bpnh9l13	vegetables.png	image/png	{"identified":true}	local	41944	vD9QCuNm2jyIwOuaPCY+9g==	2026-02-21 10:15:07.687831
18	ubtvchb75fzy7yztblftq9og8h9x	Screenshot from 2026-02-07 09-03-44.png	image/png	{"identified":true}	local	685418	HUFnpChmydP1SW7+d+Diig==	2026-02-21 12:14:14.894435
19	6fvu5ef2jcyimnd4oo55901d6sa5	customer 1.png	image/png	{"identified":true}	local	26379	DoGnmczAvsxxCHXfQIn+tg==	2026-02-23 12:37:55.825003
20	d3ze7z5bkk95okr65ftmi6gfu98g	customer house.jpg	image/jpeg	{"identified":true}	local	36538	T38R2MKg0HTX2I3UCUrhoQ==	2026-02-23 12:37:56.326148
21	36282h2byxoioq30csq5mqgmphor	logo.jpeg	image/jpeg	{"identified":true}	local	22400	jl6yRAWPOl8M+oO/pe1gvg==	2026-02-24 01:34:54.13753
22	2aso4dabq6iaap4wf4om6ydngzyf	siddhadnt.jpeg	image/jpeg	{"identified":true}	local	12977	C7awdn7CLs24BA7wU3fmiQ==	2026-02-24 03:43:13.967668
23	cq4i0f7bqrg4w90juvy1fp32d3ye	siddhadnt.jpeg	image/jpeg	{"identified":true}	local	12977	C7awdn7CLs24BA7wU3fmiQ==	2026-02-24 03:43:45.790956
24	ary24yi1hov1l38yb3dpin9pxeub	siddhadnt.jpeg	image/jpeg	{"identified":true}	local	12977	C7awdn7CLs24BA7wU3fmiQ==	2026-02-24 03:44:10.748379
25	5pfk9e5jhpuxmgw9hziktiku8nz9	Screenshot from 2026-02-07 07-40-01.png	image/png	{"identified":true}	local	103977	MMlazV5x2k5IlxCZxk25dg==	2026-02-27 00:42:17.82227
26	vfairils192g7tnzi91fz2kdkp79	Screenshot from 2026-02-07 11-43-48.png	image/png	{"identified":true}	local	245237	7Raaaj42A+rSmSsDa6Ankw==	2026-03-04 06:38:37.306322
\.


--
-- Data for Name: active_storage_variant_records; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.active_storage_variant_records (id, blob_id, variation_digest) FROM stdin;
\.


--
-- Data for Name: affiliates; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.affiliates (id, first_name, last_name, middle_name, email, mobile, address, city, state, pincode, pan_no, gst_no, commission_percentage, bank_name, account_no, ifsc_code, account_holder_name, account_type, upi_id, status, notes, auto_generated_password, joining_date, created_at, updated_at, company_name, username) FROM stdin;
\.


--
-- Data for Name: ar_internal_metadata; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.ar_internal_metadata (key, value, created_at, updated_at) FROM stdin;
schema_sha1	9c6777daaa6ce85cc74b26c38000144a7834a947	2026-02-12 02:44:06.897761	2026-02-12 02:44:06.897764
environment	development	2026-02-12 02:44:05.79552	2026-02-22 10:18:57.284237
\.


--
-- Data for Name: banners; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.banners (id, title, description, redirect_link, display_start_date, display_end_date, display_location, status, display_order, image, created_at, updated_at, image_url, r2_image_url) FROM stdin;
\.


--
-- Data for Name: booking_invoices; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.booking_invoices (id, booking_id, customer_id, invoice_number, invoice_date, due_date, subtotal, tax_amount, discount_amount, total_amount, payment_status, status, notes, invoice_items, paid_at, created_at, updated_at, share_token) FROM stdin;
27	75	481	INV2026032923147C	2026-03-29 06:30:36.262241	2026-04-28 06:30:36.262275	700.00	35.00	0.00	735.00	1	1	Invoice generated for booking #BK202603196879	[{"product_id":41,"product_name":"SUNFLOWER OIL [1LTR]","quantity":"2.0","price":"350.0","total":"700.0"}]	\N	2026-03-29 06:30:37.612659	2026-03-29 06:30:37.612659	zWuY78arR4dj3m4GxAAKY7SzvRIfSOUckTfPZiFHYy4
28	82	481	INV202603295B21A4	2026-03-29 06:42:22.716035	2026-04-28 06:42:22.716106	1500.00	75.00	0.00	1575.00	1	1	Invoice generated for booking #BK2026032465D905	[{"product_id":35,"product_name":"DESI COW GHEE [500ML]","quantity":"2.0","price":"750.0","total":"1500.0"}]	\N	2026-03-29 06:42:24.812446	2026-03-29 06:42:24.812446	p5DaJaQNml1P8lMvKZ7n8LcaX2FTkkMhOJAfnr7LNaA
29	125	486	INV2026032972464D	2026-03-29 06:54:05.464519	2026-04-28 06:54:05.464578	1.00	0.00	0.00	1.00	1	1	Invoice generated for booking #BK202603299963	[{"product_id":50,"product_name":"Test product","quantity":"1.0","price":"1.0","total":"1.0"}]	\N	2026-03-29 06:54:05.638192	2026-03-29 06:54:05.638192	71rYwLfQMWl2XvIO6gGedxLdYtmFh0Srvu5LIW8cdNo
30	125	486	INV20260329D799F1	2026-03-29 06:54:06.138785	2026-04-28 06:54:06.138842	1.00	0.00	0.00	1.00	1	1	Invoice generated for booking #BK202603299963	[{"product_id":50,"product_name":"Test product","quantity":"1.0","price":"1.0","total":"1.0"}]	\N	2026-03-29 06:54:06.306674	2026-03-29 06:54:06.306674	cHU-HTR38aousBUkcd4zZWpWOu6KxRrQjrPeXZp4CzI
31	126	486	INV202603295C801F	2026-03-29 07:04:53.909571	2026-04-28 07:04:53.909669	1.00	0.00	0.00	1.00	1	1	Invoice generated for booking #BK202603291670	[{"product_id":50,"product_name":"Test product","quantity":"1.0","price":"1.0","total":"1.0"}]	\N	2026-03-29 07:04:54.083447	2026-03-29 07:04:54.083447	iyLNM1yNH3gsgggyrl82QcMV4FUhtY4zJZ3yGVvp3Gs
32	128	486	INV20260329A80763	2026-03-29 07:13:49.210913	2026-04-28 07:13:49.210941	1.00	0.00	0.00	1.00	1	1	Invoice generated for booking #BK202603295419	[{"product_id":50,"product_name":"Test product","quantity":"1.0","price":"1.0","total":"1.0"}]	\N	2026-03-29 07:13:49.358083	2026-03-29 07:13:49.358083	YMSKLXILHhlzKVA716BrYoqmLhDDizxnlfMA-jE1xFU
33	129	486	INV20260329A4CB74	2026-03-29 10:04:26.671496	2026-04-28 10:04:26.671553	1.00	0.00	0.00	1.00	1	1	Invoice generated for booking #BK202603299884	[{"product_id":50,"product_name":"Test product","quantity":"1.0","price":"1.0","total":"1.0"}]	\N	2026-03-29 10:04:27.08547	2026-03-29 10:04:27.08547	qvh_zk7rsNxYqv3MysyZmzvY02FfiQaJsgI4Yfses04
\.


--
-- Data for Name: booking_items; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.booking_items (id, booking_id, product_id, quantity, price, total, created_at, updated_at) FROM stdin;
94	75	41	2.00	350.0	700.0	2026-03-19 09:39:03.137552	2026-03-19 09:39:03.137552
95	76	42	1.00	650.0	650.0	2026-03-21 07:07:02.040847	2026-03-21 07:07:02.040847
96	77	37	1.00	600.0	600.0	2026-03-21 07:08:58.493462	2026-03-21 07:08:58.493462
97	78	38	1.00	270.0	270.0	2026-03-23 04:42:26.834461	2026-03-23 04:42:26.834461
98	79	35	1.00	750.0	750.0	2026-03-24 03:55:24.662452	2026-03-24 03:55:24.662452
99	80	46	2.00	130.0	260.0	2026-03-24 04:29:49.361441	2026-03-24 04:29:49.361441
100	80	47	1.00	130.0	130.0	2026-03-24 04:29:55.850262	2026-03-24 04:29:55.850262
101	81	35	2.00	750.0	1500.0	2026-03-24 10:58:24.980045	2026-03-24 10:58:24.980045
102	82	35	2.00	750.0	1500.0	2026-03-24 10:59:22.105473	2026-03-24 10:59:22.105473
103	83	35	2.00	750.0	1500.0	2026-03-24 11:00:36.5163	2026-03-24 11:00:36.5163
104	84	35	2.00	750.0	1500.0	2026-03-24 11:01:11.300621	2026-03-24 11:01:11.300621
105	85	47	3.00	130.0	390.0	2026-03-25 03:25:44.56704	2026-03-25 03:25:44.56704
106	86	46	1.00	130.0	130.0	2026-03-25 04:22:59.963128	2026-03-25 04:22:59.963128
107	87	49	1.00	100.0	100.0	2026-03-25 04:28:00.682795	2026-03-25 04:28:00.682795
108	88	49	1.00	100.0	100.0	2026-03-25 04:33:55.775067	2026-03-25 04:33:55.775067
109	89	49	1.00	100.0	100.0	2026-03-25 06:48:39.967015	2026-03-25 06:48:39.967015
110	90	35	1.00	750.0	750.0	2026-03-25 07:07:15.603734	2026-03-25 07:07:15.603734
111	91	41	1.00	350.0	350.0	2026-03-25 07:13:21.880822	2026-03-25 07:13:21.880822
112	91	49	3.00	100.0	300.0	2026-03-25 07:13:24.70646	2026-03-25 07:13:24.70646
113	91	47	1.00	130.0	130.0	2026-03-25 07:13:27.091765	2026-03-25 07:13:27.091765
114	92	35	1.00	750.0	750.0	2026-03-25 07:50:28.97529	2026-03-25 07:50:28.97529
115	93	35	1.00	750.0	750.0	2026-03-25 07:50:48.115913	2026-03-25 07:50:48.115913
116	94	35	2.00	750.0	1500.0	2026-03-26 03:34:08.654629	2026-03-26 03:34:08.654629
117	95	49	1.00	100.0	100.0	2026-03-26 04:41:57.239112	2026-03-26 04:41:57.239112
118	96	49	1.00	100.0	100.0	2026-03-26 04:42:01.431032	2026-03-26 04:42:01.431032
119	97	49	1.00	100.0	100.0	2026-03-26 04:42:01.850392	2026-03-26 04:42:01.850392
120	98	49	1.00	100.0	100.0	2026-03-26 04:42:06.133447	2026-03-26 04:42:06.133447
121	99	49	1.00	100.0	100.0	2026-03-26 04:42:38.927271	2026-03-26 04:42:38.927271
122	99	43	1.00	490.0	490.0	2026-03-26 04:42:39.238588	2026-03-26 04:42:39.238588
123	100	41	1.00	350.0	350.0	2026-03-26 04:46:27.68721	2026-03-26 04:46:27.68721
124	100	49	4.00	100.0	400.0	2026-03-26 04:46:37.852671	2026-03-26 04:46:37.852671
125	100	43	1.00	490.0	490.0	2026-03-26 04:46:40.208235	2026-03-26 04:46:40.208235
126	101	49	1.00	100.0	100.0	2026-03-26 05:01:26.611069	2026-03-26 05:01:26.611069
127	101	43	1.00	490.0	490.0	2026-03-26 05:01:29.399495	2026-03-26 05:01:29.399495
128	102	35	1.00	750.0	750.0	2026-03-26 06:51:08.577394	2026-03-26 06:51:08.577394
129	103	35	1.00	750.0	750.0	2026-03-26 06:52:54.11984	2026-03-26 06:52:54.11984
130	104	49	1.00	100.0	100.0	2026-03-26 06:56:48.084677	2026-03-26 06:56:48.084677
131	105	49	1.00	100.0	100.0	2026-03-26 07:25:17.899387	2026-03-26 07:25:17.899387
132	106	49	1.00	100.0	100.0	2026-03-26 08:33:05.094017	2026-03-26 08:33:05.094017
133	107	49	2.00	100.0	200.0	2026-03-26 08:43:15.064452	2026-03-26 08:43:15.064452
134	108	49	1.00	100.0	100.0	2026-03-26 08:47:47.050134	2026-03-26 08:47:47.050134
135	109	49	1.00	100.0	100.0	2026-03-26 10:19:50.183308	2026-03-26 10:19:50.183308
136	110	35	2.00	750.0	1500.0	2026-03-28 12:35:45.592594	2026-03-28 12:35:45.592594
137	111	35	2.00	750.0	1500.0	2026-03-28 12:35:55.862009	2026-03-28 12:35:55.862009
138	112	35	2.00	750.0	1500.0	2026-03-28 12:35:55.854155	2026-03-28 12:35:55.854155
139	113	35	2.00	750.0	1500.0	2026-03-28 12:36:23.330823	2026-03-28 12:36:23.330823
140	114	35	2.00	750.0	1500.0	2026-03-28 12:36:42.774151	2026-03-28 12:36:42.774151
141	115	47	1.00	130.0	130.0	2026-03-29 01:44:42.876341	2026-03-29 01:44:42.876341
142	115	49	1.00	100.0	100.0	2026-03-29 01:44:57.267767	2026-03-29 01:44:57.267767
143	116	38	1.00	270.0	270.0	2026-03-29 04:02:02.603738	2026-03-29 04:02:02.603738
144	117	47	1.00	130.0	130.0	2026-03-29 04:08:17.329975	2026-03-29 04:08:17.329975
145	118	47	1.00	130.0	130.0	2026-03-29 04:13:19.906712	2026-03-29 04:13:19.906712
146	119	38	1.00	270.0	270.0	2026-03-29 05:29:01.903455	2026-03-29 05:29:01.903455
147	120	49	1.00	100.0	100.0	2026-03-29 05:33:23.187119	2026-03-29 05:33:23.187119
148	121	50	1.00	1.0	1.0	2026-03-29 05:38:48.879461	2026-03-29 05:38:48.879461
149	122	50	1.00	1.0	1.0	2026-03-29 06:02:59.706512	2026-03-29 06:02:59.706512
150	123	50	1.00	1.0	1.0	2026-03-29 06:21:25.334551	2026-03-29 06:21:25.334551
151	124	50	1.00	1.0	1.0	2026-03-29 06:33:33.676361	2026-03-29 06:33:33.676361
152	125	50	1.00	1.0	1.0	2026-03-29 06:53:33.636613	2026-03-29 06:53:33.636613
153	126	50	1.00	1.0	1.0	2026-03-29 07:04:16.126595	2026-03-29 07:04:16.126595
154	127	50	1.00	1.0	1.0	2026-03-29 07:04:17.114926	2026-03-29 07:04:17.114926
155	128	50	1.00	1.0	1.0	2026-03-29 07:13:06.581735	2026-03-29 07:13:06.581735
156	129	50	1.00	1.0	1.0	2026-03-29 10:03:42.01115	2026-03-29 10:03:42.01115
157	130	50	1.00	1.0	1.0	2026-03-29 10:06:24.582848	2026-03-29 10:06:24.582848
158	131	38	1.00	270.0	270.0	2026-03-29 10:06:56.365203	2026-03-29 10:06:56.365203
159	132	38	1.00	270.0	270.0	2026-03-29 10:07:19.957879	2026-03-29 10:07:19.957879
160	133	40	1.00	345.0	345.0	2026-03-29 10:08:36.67652	2026-03-29 10:08:36.67652
161	134	40	1.00	345.0	345.0	2026-03-29 10:09:02.431239	2026-03-29 10:09:02.431239
162	135	50	1.00	1.0	1.0	2026-03-29 10:17:20.219863	2026-03-29 10:17:20.219863
163	135	40	1.00	345.0	345.0	2026-03-29 10:17:26.954002	2026-03-29 10:17:26.954002
164	136	45	1.00	530.0	530.0	2026-03-29 10:18:08.048529	2026-03-29 10:18:08.048529
165	137	50	1.00	1.0	1.0	2026-03-29 10:19:09.361031	2026-03-29 10:19:09.361031
166	138	50	1.00	1.0	1.0	2026-03-29 10:23:52.37302	2026-03-29 10:23:52.37302
167	139	50	1.00	1.0	1.0	2026-03-29 10:27:58.141785	2026-03-29 10:27:58.141785
168	140	50	1.00	1.0	1.0	2026-03-29 10:31:11.072966	2026-03-29 10:31:11.072966
169	141	50	1.00	1.0	1.0	2026-03-29 10:41:18.872434	2026-03-29 10:41:18.872434
\.


--
-- Data for Name: booking_schedules; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.booking_schedules (id, customer_id, product_id, schedule_type, frequency, start_date, end_date, quantity, delivery_time, delivery_address, pincode, latitude, longitude, status, next_booking_date, total_bookings_generated, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: bookings; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.bookings (id, customer_id, user_id, booking_number, booking_date, status, payment_method, payment_status, subtotal, tax_amount, discount_amount, total_amount, notes, booking_items, customer_name, customer_email, customer_phone, delivery_address, invoice_generated, invoice_number, cash_received, change_amount, created_at, updated_at, booking_schedule_id, stage, courier_service, tracking_number, shipping_charges, expected_delivery_date, delivery_person, delivery_contact, delivered_to, delivery_time, customer_satisfaction, processing_team, expected_completion_time, estimated_processing_time, estimated_delivery_time, package_weight, package_dimensions, quality_status, cancellation_reason, return_reason, return_condition, refund_amount, refund_method, transition_notes, stage_history, stage_updated_at, stage_updated_by, store_id, subscription_id, is_subscription, final_amount_after_discount, delivery_person_id, franchise_id, quick_invoice, booked_by, selected_shop_address, delivery_store, cashfree_order_id, payment_session_id, cashfree_payment_id, gateway_response, payment_gateway, payment_initiated_at, payment_completed_at) FROM stdin;
80	484	\N	BK202603241314	2026-03-24 04:29:43.560732	confirmed	2	unpaid	390.0	19.5	\N	409.5	\N	\N	Dharani Kannan	tkdharani@gmail.com	9655761911	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-24 04:29:49.085987	2026-03-24 04:29:49.085987	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	409.5	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
84	481	\N	BK202603243C2E44	2026-03-24 11:01:08.171152	draft	6	\N	1500.0	75.0	\N	1575.0	\N	\N	raghunandan kt	drwisedev@gmail.com	9844070041	123 Test Street, Test City	\N	\N	\N	\N	2026-03-24 11:01:11.052037	2026-03-24 11:01:11.052037	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cashfree	\N	\N
86	484	\N	BK202603251687	2026-03-25 04:22:50.029144	confirmed	2	unpaid	130.0	6.5	\N	136.5	\N	\N	Dharani Kannan	tkdharani@gmail.com	9655761911	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-25 04:22:59.103605	2026-03-25 04:22:59.103605	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	136.5	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
89	484	1	BK20260325333240	2026-03-24 18:30:00	completed	0	unpaid	100.0	5.0	0.0	105.0		\N	Dharani Kannan	tkdharani@gmail.com	9655761911	assa	\N	\N	\N	0.0	2026-03-25 06:48:39.715889	2026-03-25 06:48:39.715889	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
92	486	\N	BK202603258061	2026-03-25 07:50:23.660811	confirmed	5	paid	750.0	37.5	\N	787.5	\N	\N	Payment Test	paymenttest@test.com	9876543210	123 Test Street, Test City	\N	\N	\N	\N	2026-03-25 07:50:28.556241	2026-03-25 07:50:40.034921	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	787.5	\N	\N	f	admin	\N	\N	MKS_20260325132038_40DA3D6B	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"787.5"}	cashfree	2026-03-25 07:50:33.134022	2026-03-25 07:50:39.624904
78	484	\N	BK202603238636	2026-03-23 04:42:26.601017	completed	2	unpaid	270.0	13.5	\N	283.5	\N	\N	Dharani Kannan	tkdharani@gmail.com	9655761911	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-23 04:42:26.799151	2026-03-25 12:18:59.858635	\N	\N	\N	\N	\N	\N	\N	\N	\N	2026-03-25 06:47:00	5	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	Delivered to home 	[{"from_stage":"confirmed","to_stage":"delivered","timestamp":"2026-03-25T17:47:48.958+05:30","user_id":1,"user_name":"Admin User","delivery_person":"","delivery_time":"2026-03-25T12:17","customer_satisfaction":"5"},{"from_stage":"delivered","to_stage":"completed","timestamp":"2026-03-25T17:48:59.216+05:30","user_id":1,"user_name":"Admin User","notes":"Delivered to home "}]	2026-03-25 12:18:59.217031	1	\N	\N	\N	283.5	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
93	486	\N	BK202603253650	2026-03-25 07:50:45.255746	confirmed	5	paid	750.0	37.5	\N	787.5	\N	\N	Payment Test	paymenttest@test.com	9876543210	123 Test Street, Test City	\N	\N	\N	\N	2026-03-25 07:50:47.7166	2026-03-25 07:50:53.549309	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	787.5	\N	\N	f	admin	\N	\N	MKS_20260325132052_29ADA307	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"787.5"}	cashfree	2026-03-25 07:50:51.710411	2026-03-25 07:50:53.187926
95	481	\N	BK202603265323	2026-03-26 04:41:56.994696	confirmed	5	paid	100.0	5.0	\N	105.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 04:41:57.203324	2026-03-26 04:41:58.393479	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	MKS_20260326101158_BB744B41	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"105.0"}	cashfree	2026-03-26 04:41:57.627136	2026-03-26 04:41:58.363759
102	\N	\N	BK202603263497	2026-03-26 06:51:00.889943	confirmed	5	paid	750.0	37.5	\N	787.5	\N	\N	Test Customer	test@cod.com	9876543210	PICKUP: Test Shop Location	\N	\N	\N	\N	2026-03-26 06:51:07.963248	2026-03-26 06:51:35.448241	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	787.5	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"787.5"}	cash	\N	2026-03-26 06:51:17.582657
97	481	\N	BK202603269319	2026-03-26 04:42:01.632651	confirmed	5	paid	100.0	5.0	\N	105.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 04:42:01.817736	2026-03-26 04:42:04.587415	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	MKS_20260326101204_F36965B7	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"105.0"}	cashfree	2026-03-26 04:42:04.4305	2026-03-26 04:42:04.556365
112	481	\N	BK202603285228	2026-03-28 12:35:50.778954	confirmed	5	paid	1500.0	75.0	\N	1575.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-28 12:35:54.802204	2026-03-28 12:36:41.255952	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"1575.0"}	cash	\N	2026-03-28 12:36:41.000544
116	486	\N	BK202603295078	2026-03-29 02:51:41.364553	confirmed	5	unpaid	270.0	13.5	\N	283.5	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 04:02:01.130643	2026-03-29 04:02:01.130643	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	283.5	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
106	481	\N	BK202603261832	2026-03-26 08:33:03.000907	confirmed	5	paid	100.0	5.0	\N	105.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 08:33:04.840023	2026-03-26 08:33:15.093713	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"105.0"}	cash	\N	2026-03-26 08:33:08.803886
108	481	\N	BK202603269007	2026-03-26 08:47:44.960094	confirmed	5	paid	100.0	5.0	\N	105.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 08:47:46.800437	2026-03-26 08:47:55.10005	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"105.0"}	cash	\N	2026-03-26 08:47:50.236188
104	487	1	BK20260326530FF8	2026-03-25 18:30:00	completed	0	paid	100.0	5.0	0.0	105.0		\N	Ajji G	mamathanagaraju08@gmail.com	9739001874	xdsds	t	INV20260326A71239	\N	0.0	2026-03-26 06:56:47.818555	2026-03-26 14:07:25.722023	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
110	481	\N	BK202603283269	2026-03-28 12:35:42.249109	confirmed	5	paid	1500.0	75.0	\N	1575.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-28 12:35:45.320334	2026-03-28 12:36:01.489369	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"1575.0"}	cash	\N	2026-03-28 12:35:51.488269
113	481	\N	BK202603289869	2026-03-28 12:36:19.63482	draft	5	paid	1500.0	75.0	\N	1575.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-28 12:36:23.027271	2026-03-28 12:37:01.998063	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"1575.0"}	cash	\N	2026-03-28 12:37:01.533486
100	481	\N	BK202603262829	2026-03-26 04:46:17.477381	draft	5	unpaid	1240.0	62.0	\N	1302.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	t	INV202603264282FD	\N	\N	2026-03-26 04:46:27.363644	2026-03-29 01:36:34.734264	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1302.0	\N	\N	f	admin	\N	\N	MKS_20260326101648_095F7F98	\N	\N	{"failure_reason":"Transaction failed","failed_at":"2026-03-29T07:06:04.393+05:30"}	cashfree	2026-03-26 04:46:42.49063	2026-03-26 04:46:48.943235
119	486	\N	BK202603293522	2026-03-29 05:29:00.344689	draft	6	unpaid	270.0	13.5	\N	283.5	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 05:29:01.610417	2026-03-29 05:29:10.323473	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	283.5	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329105908_BEC51955	session_aQBZJ_ChkcO40idNQIxldmhD7pwZ6F416qCkXYE1BrBlzgEQndV6uMEhVryDgU_7Kxk7RjS220CMGJt0sEQKiA_G2TDmjRSOaixXhrTbFW7UhO1uJANEUVuf3Hsujgpaymentpayment	\N	\N	cashfree	2026-03-29 05:29:09.099174	\N
122	486	\N	BK202603292270	2026-03-29 06:02:59.017736	draft	6	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 06:02:59.67041	2026-03-29 06:03:01.05382	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329113300_EBADED60	\N	\N	{"failure_reason":"authentication Failed","failed_at":"2026-03-29T11:33:01.022+05:30"}	cashfree	2026-03-29 06:03:00.578042	\N
124	486	\N	BK202603295209	2026-03-29 06:33:33.464762	draft	6	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 06:33:33.64216	2026-03-29 06:33:35.051771	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329120334_9C12F08C	session_9UQULUDo-nLZhYJRQIDcD-n8TAmOV8IRLWc5DF6R0eirhC24LbWTJAhp8B_gwW-ypYIWvi8Rw5yQ80BVtFqKPzXZLzmYYyrxLPgHS57X69iimImRYcGWeXuF_1tt	\N	\N	cashfree	2026-03-29 06:33:34.592743	\N
82	481	\N	BK2026032465D905	2026-03-24 10:59:13.561826	draft	2	paid	1500.0	75.0	\N	1575.0	\N	\N	raghunandan kt	drwisedev@gmail.com	9844070041	123 Test Street, Test City	\N	\N	\N	\N	2026-03-24 10:59:21.464158	2026-03-29 06:42:12.320612	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	webhook_test_order_82	\N	test_payment_real_82	{"cf_payment_id":"test_payment_real_82","payment_method":"upi","order_status":"PAID","payment_amount":100.0,"bank_reference":"test_ref_82","auth_id":"test_auth_82"}	cashfree	\N	2026-03-29 06:42:05.432614
77	482	\N	BK202603211041	2026-03-21 07:08:58.307731	confirmed	2	unpaid	600.0	30.0	\N	630.0	\N	\N	John Doe	gepeucoubourou-9168@yopmail.com	7349673793	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-21 07:08:58.460299	2026-03-21 07:08:58.460299	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	630.0	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
79	484	\N	BK202603243672	2026-03-24 03:55:21.825438	confirmed	2	unpaid	750.0	37.5	\N	787.5	\N	\N	Dharani Kannan	tkdharani@gmail.com	9655761911	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-24 03:55:24.419089	2026-03-24 03:55:24.419089	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	787.5	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
83	481	\N	BK20260324C183D2	2026-03-24 11:00:29.742986	draft	6	\N	1500.0	75.0	\N	1575.0	\N	\N	raghunandan kt	drwisedev@gmail.com	9844070041	123 Test Street, Test City	\N	\N	\N	\N	2026-03-24 11:00:36.265809	2026-03-24 11:00:36.265809	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cashfree	\N	\N
85	484	\N	BK202603256117	2026-03-25 03:25:39.452761	confirmed	2	unpaid	390.0	19.5	\N	409.5	\N	\N	Dharani Kannan	tkdharani@gmail.com	9655761911	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-25 03:25:43.6437	2026-03-25 03:25:43.6437	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	409.5	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
87	484	\N	BK202603253240	2026-03-25 04:27:56.933892	confirmed	2	unpaid	100.0	5.0	\N	105.0	\N	\N	Dharani Kannan	tkdharani@gmail.com	9655761911	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-25 04:28:00.403264	2026-03-25 04:28:00.403264	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
88	484	\N	BK202603254355	2026-03-25 04:33:54.243829	confirmed	2	unpaid	100.0	5.0	\N	105.0	\N	\N	Dharani Kannan	tkdharani@gmail.com	9655761911	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-25 04:33:55.514376	2026-03-25 04:33:55.514376	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
130	486	\N	BK202603292302	2026-03-29 10:06:24.308278	confirmed	5	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:06:24.55184	2026-03-29 10:06:24.55184	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
132	486	\N	BK202603299750	2026-03-29 10:07:19.777825	confirmed	5	unpaid	270.0	13.5	\N	283.5	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:07:19.927351	2026-03-29 10:07:19.927351	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	283.5	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
107	481	\N	BK202603268892	2026-03-26 08:43:12.506946	confirmed	5	paid	200.0	10.0	\N	210.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 08:43:14.657575	2026-03-26 08:43:24.77067	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	210.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"210.0"}	cash	\N	2026-03-26 08:43:18.954632
90	486	\N	BK202603251338	2026-03-25 07:07:12.354208	draft	5	paid	750.0	37.5	\N	787.5	\N	\N	Payment Test	paymenttest@test.com	9876543210	123 Test Street, Test City	\N	\N	\N	\N	2026-03-25 07:07:15.343568	2026-03-25 07:07:23.606998	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	787.5	\N	\N	f	admin	\N	\N	MKS_20260325123722_B35BB1B2	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"787.5"}	cashfree	2026-03-25 07:07:18.537246	2026-03-25 07:07:23.351688
133	486	\N	BK202603297478	2026-03-29 10:08:36.493538	confirmed	5	unpaid	345.0	0.0	\N	345.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:08:36.645406	2026-03-29 10:08:36.645406	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	345.0	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
91	484	\N	BK202603252619	2026-03-25 07:13:17.904197	confirmed	5	paid	780.0	39.0	\N	819.0	\N	\N	Customer Name	tkdharani@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-25 07:13:21.618501	2026-03-25 07:13:34.571703	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	819.0	\N	\N	f	admin	\N	\N	MKS_20260325124333_B4FBCAB4	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"819.0"}	cashfree	2026-03-25 07:13:29.419241	2026-03-25 07:13:34.252562
94	481	\N	BK2026032628F16A	2026-03-26 03:34:05.037557	confirmed	6	\N	1500.0	75.0	\N	1575.0	\N	\N	raghunandan kt	drwisedev@gmail.com	9844070041	123 Test Street, Test City, Test State - 12345	\N	\N	\N	\N	2026-03-26 03:34:08.386923	2026-03-26 03:34:16.858054	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cashfree	\N	\N
81	481	\N	BK20260324E2C6A5	2026-03-24 10:58:13.645738	confirmed	2	paid	1500.0	75.0	\N	1575.0	\N	\N	raghunandan kt	drwisedev@gmail.com	9844070041	123 Test Street, Test City	\N	\N	\N	\N	2026-03-24 10:58:24.686232	2026-03-26 03:38:30.588463	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	TEST_PAYMENT_123	{"cf_payment_id":"TEST_PAYMENT_123","payment_method":"upi"}	cashfree	\N	2026-03-26 03:38:23.691343
141	486	\N	BK202603291709	2026-03-29 10:41:18.672402	confirmed	5	unpaid	1.0	0.0	\N	1.0	\N	\N	Payment Test	paymenttest@test.com	9876543210	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-29 10:41:18.841403	2026-03-29 10:41:18.841403	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd	\N	\N	\N	\N	cash	\N	\N
96	481	\N	BK202603269770	2026-03-26 04:42:00.733774	confirmed	5	paid	100.0	5.0	\N	105.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 04:42:01.394745	2026-03-26 04:42:02.522262	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	MKS_20260326101202_7DF73386	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"105.0"}	cashfree	2026-03-26 04:42:01.841465	2026-03-26 04:42:02.47948
76	482	\N	BK202603211826	2026-03-21 07:07:01.604412	confirmed	5	unpaid	650.0	32.5	\N	682.5	\N	\N	John Doe	gepeucoubourou-9168@yopmail.com	7349673793	Sample Address, Street 1, City Name, State Name - 123456	t	INV20260326581348	\N	\N	2026-03-21 07:07:02.009844	2026-03-26 03:40:09.769026	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	682.5	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
98	481	\N	BK202603263124	2026-03-26 04:42:05.895081	confirmed	5	paid	100.0	5.0	\N	105.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 04:42:06.099374	2026-03-26 04:42:06.615006	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	MKS_20260326101206_2A126032	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"105.0"}	cashfree	2026-03-26 04:42:06.443327	2026-03-26 04:42:06.581358
99	481	\N	BK202603269739	2026-03-26 04:42:38.567331	confirmed	5	paid	590.0	29.5	\N	619.5	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 04:42:38.893055	2026-03-26 04:42:39.744988	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	619.5	\N	\N	f	admin	\N	\N	MKS_20260326101239_D8ED92FA	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"619.5"}	cashfree	2026-03-26 04:42:39.58403	2026-03-26 04:42:39.711922
101	481	\N	BK202603262029	2026-03-26 05:01:23.746519	confirmed	5	paid	590.0	29.5	\N	619.5	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 05:01:26.345019	2026-03-26 05:01:35.819676	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	619.5	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"619.5"}	cash	\N	2026-03-26 05:01:31.665863
103	\N	\N	BK202603268254	2026-03-26 06:52:48.751418	draft	5	\N	750.0	37.5	\N	787.5	\N	\N	Test Customer	test@cod.com	9876543210	PICKUP: Shop 1	\N	\N	\N	\N	2026-03-26 06:52:53.192816	2026-03-26 06:52:53.192816	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	787.5	\N	\N	f	admin	\N	\N	\N	\N	\N	\N	cash	\N	\N
105	481	\N	BK202603265071	2026-03-26 07:25:15.288773	confirmed	5	paid	100.0	5.0	\N	105.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 07:25:17.645312	2026-03-26 07:25:32.072861	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"105.0"}	cash	\N	2026-03-26 07:25:22.71677
109	481	\N	BK202603269097	2026-03-26 10:19:43.744281	confirmed	5	paid	100.0	5.0	\N	105.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-26 10:19:49.286263	2026-03-26 10:19:56.883258	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"105.0"}	cash	\N	2026-03-26 10:19:56.271183
111	481	\N	BK202603286450	2026-03-28 12:35:50.777371	confirmed	5	paid	1500.0	75.0	\N	1575.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-28 12:35:54.796108	2026-03-28 12:36:21.036987	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"1575.0"}	cash	\N	2026-03-28 12:36:20.533182
117	486	\N	BK202603298827	2026-03-29 04:08:15.465939	confirmed	5	unpaid	130.0	6.5	\N	136.5	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 04:08:17.066596	2026-03-29 04:08:17.066596	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	136.5	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
114	481	\N	BK202603287537	2026-03-28 12:36:39.329502	draft	5	paid	1500.0	75.0	\N	1575.0	\N	\N	Customer Name	drwisedev@gmail.com	9876543210	PICKUP: abc,bcd,	\N	\N	\N	\N	2026-03-28 12:36:42.417167	2026-03-28 12:37:18.393942	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1575.0	\N	\N	f	admin	\N	\N	\N	\N	\N	{"payment_method":"cod","order_status":"COMPLETED","payment_amount":"1575.0"}	cash	\N	2026-03-28 12:37:16.930648
115	486	\N	BK202603298039	2026-03-29 01:44:34.449158	confirmed	2	unpaid	230.0	11.5	\N	241.5	\N	\N	Payment Test	paymenttest@test.com	9876543210	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-29 01:44:42.606375	2026-03-29 01:44:42.606375	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	241.5	\N	\N	f	admin	\N	abc,bcd	\N	\N	\N	\N	cash	\N	\N
118	486	\N	BK202603295267	2026-03-29 04:12:45.638318	confirmed	5	unpaid	130.0	6.5	\N	136.5	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 04:13:18.460375	2026-03-29 04:13:18.460375	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	136.5	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
120	486	\N	BK202603299503	2026-03-29 05:33:21.109695	draft	6	unpaid	100.0	5.0	\N	105.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 05:33:22.825499	2026-03-29 05:33:29.387847	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	105.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329110326_114874F0	session_t1c8xizXsC6nPZnEWSiupbBVQhrtsTivmJgNy7RIad7B8fOVYZupRhuefi626mZU3lOBda-JOYIUj1_zOkaz0DsVWrHG1NmLOL0AhnexGSbRGvvCYLbuAXUwxG8z7gpaymentpayment	\N	\N	cashfree	2026-03-29 05:33:27.45196	\N
121	486	\N	BK202603291596	2026-03-29 05:38:45.035273	draft	6	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 05:38:48.622463	2026-03-29 05:38:57.6234	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329110856_DFF55C67	session_lvBy0maSef4aHZ1lxq45Vaj0ltMz00DpT6fnGEhmWBdIPnp_T597welEwQZWX6rJYW8WMFYPgIyaf6xST7ovXhdEHnd5CavNugMqjCgALPEsUnOYXj0YLa5skPPfTApaymentpayment	\N	\N	cashfree	2026-03-29 05:38:56.591078	\N
126	486	\N	BK202603291670	2026-03-29 07:04:15.153148	confirmed	2	paid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 07:04:16.095371	2026-03-29 07:04:51.336624	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329123416_EE6AAB25	session_TFDZ8sBYaNKGx50XsDsvdRuZTCeSYozOBaXO-OQppuAYDBvcvyqE2IWLNHE7lUya95GmGftHRzYKlgSDMMHC_8lKvhtUR4_-czHRL1Ro73u0v9lUr5MiNLu3Qt5l	5253745760	{"cf_payment_id":5253745760,"payment_method":"upi","order_status":"PAID","payment_amount":1.0,"bank_reference":"967523209146","auth_id":null}	cashfree	2026-03-29 07:04:17.014132	2026-03-29 07:04:51.196425
131	486	\N	BK202603298339	2026-03-29 10:06:56.149862	confirmed	5	unpaid	270.0	13.5	\N	283.5	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:06:56.331161	2026-03-29 10:06:56.331161	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	283.5	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
134	486	\N	BK202603292419	2026-03-29 10:09:02.246428	confirmed	5	unpaid	345.0	0.0	\N	345.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:09:02.401482	2026-03-29 10:09:02.401482	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	345.0	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
123	486	\N	BK202603298398	2026-03-29 06:21:24.825326	draft	6	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 06:21:25.304737	2026-03-29 06:21:26.723315	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329115126_3D9B85D0	session_zA4u5SkO3iH_ToMvyydoryMZ37roc3G70Us5OvpvPNjAEva3a2a1McThk0L0Q5VQwxX_Wgspk2f0XM6vn7MosBItyJDwCc0KfAtoKbkESOA2e0Gfms7uNbwXcrsD	\N	\N	cashfree	2026-03-29 06:21:26.117024	\N
75	481	\N	BK202603196879	2026-03-19 09:39:02.957287	delivered	2	paid	700.0	35.0	\N	735.0	\N	\N	raghunandan kt	raghubit040@gmail.com	9844070041	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-19 09:39:03.106065	2026-03-29 06:30:26.065119	\N	\N	\N	\N	\N	\N	\N	917975918232	\N	2026-03-20 02:43:00	5	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	[{"from_stage":"confirmed","to_stage":"out_for_delivery","timestamp":"2026-03-20T13:29:49.237+05:30","user_id":1,"user_name":"Admin User","delivery_person_id":"17","delivery_person":"","delivery_contact":"917975918232"},{"from_stage":"out_for_delivery","to_stage":"delivered","timestamp":"2026-03-20T13:43:52.993+05:30","user_id":1,"user_name":"Admin User","delivery_person":"","delivery_time":"2026-03-20T08:13","customer_satisfaction":"5"}]	2026-03-20 08:13:52.993614	1	\N	\N	\N	735.0	17	\N	f	admin	\N	\N	\N	\N	test_payment_123	{"cf_payment_id":"test_payment_123","payment_method":"upi","order_status":"PAID","payment_amount":"735.0"}	cash	\N	2026-03-29 06:30:19.346983
127	486	\N	BK202603293592	2026-03-29 07:04:16.926115	draft	6	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 07:04:17.084312	2026-03-29 07:04:19.223562	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329123418_83E4D949	session_1_HbbYf1ZEXrl8iZ93zVvTK8r5AuKVDKwNc59uZQ-Qyv3tWSclkZOkT2_m7hTd1ZeqhZq5pz2yjLvnSedgQfnZQUflG08JRWNXstMajMFfLHp06p_uZTBDdbealU	\N	\N	cashfree	2026-03-29 07:04:18.767152	\N
128	486	\N	BK202603295419	2026-03-29 07:13:06.295923	confirmed	2	paid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 07:13:06.495304	2026-03-29 07:13:47.437691	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329124306_ECB740D7	session_seYJXy20lx9Af5Z7lrNpmJ-ktbDwDWdgQyngGsnu5dW2CNi6MM6dpvzYEp8ZuJ8IMxqGWJgWZ4t1fWHhGtBYfGuheNobmithWRshDfvSh9yKgNC4i8YvAzK0pTcy	5253780159	{"cf_payment_id":5253780159,"payment_method":"upi","order_status":"PAID","payment_amount":1.0,"bank_reference":"912011262139","auth_id":null}	cashfree	2026-03-29 07:13:06.916614	2026-03-29 07:13:47.318184
135	486	\N	BK202603299933	2026-03-29 10:17:08.041589	confirmed	5	unpaid	346.0	0.0	\N	346.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:17:18.616588	2026-03-29 10:17:18.616588	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	346.0	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
137	486	\N	BK202603292375	2026-03-29 10:19:04.862714	confirmed	5	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:19:08.076431	2026-03-29 10:19:08.076431	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
125	486	\N	BK202603299963	2026-03-29 06:53:32.799215	confirmed	2	paid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 06:53:33.604453	2026-03-29 06:54:04.537799	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329122334_E5BB50BA	session_qkDbOqSCLTmhvZXdN7p9Zra91Ne5EMU7azXZlpSnM85fyQMSCK-C-o7yPFI50R3UKOjA58voEocjMpQOIW3-XhtGR1fe9oPWV3iodUWSZJNrnS1SPpe6lfFelVym	5253704533	{"cf_payment_id":5253704533,"payment_method":"upi","order_status":"PAID","payment_amount":1.0,"bank_reference":"075466707749","auth_id":null}	cashfree	2026-03-29 06:53:34.518227	2026-03-29 06:54:03.182937
129	486	\N	BK202603299884	2026-03-29 10:03:41.819754	confirmed	2	paid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:03:41.982828	2026-03-29 10:04:23.856267	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	MKS_20260329153342_43D26D56	session_O-wFG0WDwq2OYWsbad56tkjwZjcofbwt2O09LRGlVzGwIcbT3f6EBqIyOtGrxz_6l8047fQtaDHsNEv61b-CBkm8RQB_pj3j-wjTnrDxQMY73c6OOHS7fuaFxujJ	5254661112	{"cf_payment_id":"5254661112","payment_method":"upi","order_status":"PAID","payment_amount":1.0,"bank_reference":"927065988467","auth_id":null}	cashfree	2026-03-29 10:03:42.84789	2026-03-29 10:04:23.722716
136	486	\N	BK202603291331	2026-03-29 10:18:04.395767	confirmed	5	unpaid	530.0	26.5	\N	556.5	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:18:07.367645	2026-03-29 10:18:07.367645	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	556.5	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
138	486	\N	BK202603296916	2026-03-29 10:23:50.42873	confirmed	5	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:23:52.073634	2026-03-29 10:23:52.073634	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
139	486	\N	BK202603297255	2026-03-29 10:27:55.577459	confirmed	5	unpaid	1.0	0.0	\N	1.0	\N	\N	Customer Name	paymenttest@test.com	9876543210	abc,bcd,	\N	\N	\N	\N	2026-03-29 10:27:57.824112	2026-03-29 10:27:57.824112	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd,	\N	\N	\N	\N	cash	\N	\N
140	486	\N	BK202603291834	2026-03-29 10:31:09.20468	confirmed	5	unpaid	1.0	0.0	\N	1.0	\N	\N	Payment Test	paymenttest@test.com	9876543210	Sample Address, Street 1, City Name, State Name - 123456	\N	\N	\N	\N	2026-03-29 10:31:10.743647	2026-03-29 10:31:10.743647	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1.0	\N	\N	f	admin	\N	abc,bcd	\N	\N	\N	\N	cash	\N	\N
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.categories (id, name, description, image, status, display_order, created_at, updated_at, image_backup_url) FROM stdin;
11	Dairy Products	At Marali Santhe, we bring you pure, farm-fresh dairy products sourced directly from trusted local farmers. Our dairy range is rooted in traditional methods, ensuring natural taste, high nutrition, and zero compromise on quality.	\N	t	0	2026-03-19 08:15:24.703238	2026-03-19 08:15:24.703238	\N
12	Dairy & Farm Fresh	At Marali Santhe, we bring you pure, farm-fresh dairy products sourced directly from trusted local farmers. Our dairy range is rooted in traditional methods, ensuring natural taste, high nutrition, and zero compromise on quality.	\N	t	0	2026-03-19 08:17:09.223285	2026-03-19 08:17:09.223285	/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsiZGF0YSI6MTUsInB1ciI6ImJsb2JfaWQifX0=--7924a1d2f51547fc8e0255ca8e95bac974ef3fb4/rice.png
13	Natural Sweeteners	“Unprocessed • Farm Sourced • No Added Sugar” 	\N	t	0	2026-03-19 08:53:32.125964	2026-03-19 08:53:32.125964	/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsiZGF0YSI6MTYsInB1ciI6ImJsb2JfaWQifX0=--a90217915751dc7fcca4e3fe78f24dc27301e20c/vegetables.png
14	OILS 	At Marali Santhe, we follow a refined wood pressing process that blends traditional wisdom with precise extraction techniques. Our oils are produced without any harmful substances, ensuring they remain clean, safe, and unadulterated.\r\n\r\nEvery drop reflects purity—free from chemicals, free from contamination, and rich in natural goodness. With farm-sourced ingredients and careful processing, Marali Santhe Wood Pressed Oils deliver authenticity, nutrition, and trust in every use.	\N	t	0	2026-03-19 09:09:10.004612	2026-03-19 09:09:10.004612	\N
15	Grains & Millets	At Marali Santhe, our Grains & Millets collection brings together carefully sourced staples rooted in traditional food culture. From native rice varieties to nutrient-rich millets like ragi, jowar, and foxtail, every product is selected with a focus on quality and authenticity.\r\n\r\nSourced directly from farms, our grains and millets are free from harmful substances and unnecessary processing, ensuring you receive food in its most natural form. Whether for daily meals or traditional recipes, they offer a wholesome and balanced way to nourish your family.\r\n\r\n	\N	t	0	2026-03-19 09:28:30.674074	2026-03-19 09:28:30.674074	\N
\.


--
-- Data for Name: client_requests; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.client_requests (id, title, description, status, priority, customer_id, created_at, updated_at, stage, stage_updated_at, stage_history, assignee_id, department, estimated_resolution_time, actual_resolution_time, name, email, phone_number, ticket_number, admin_response, resolved_by_id, submitted_at, resolved_at) FROM stdin;
\.


--
-- Data for Name: coupons; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.coupons (id, code, description, discount_type, discount_value, minimum_amount, maximum_discount, usage_limit, used_count, valid_from, valid_until, status, applicable_products, applicable_categories, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: customer_addresses; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.customer_addresses (id, customer_id, name, mobile, address_type, address, landmark, city, state, pincode, latitude, longitude, is_default, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: customer_formats; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.customer_formats (id, customer_id, pattern, quantity, product_id, delivery_person_id, status, created_at, updated_at, days) FROM stdin;
\.


--
-- Data for Name: customer_wallets; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.customer_wallets (id, customer_id, balance, status, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.customers (id, first_name, last_name, email, mobile, created_at, updated_at, longitude, latitude, whatsapp_number, auto_generated_password, location_obtained_at, location_accuracy, password_digest, middle_name, address, birth_date, gender, marital_status, pan_no, gst_no, company_name, occupation, annual_income, emergency_contact_name, emergency_contact_number, blood_group, nationality, preferred_language, notes, status, is_registered_by_mobile, password_reset_token, password_reset_sent_at) FROM stdin;
484	Dharani	Kannan	tkdharani@gmail.com	9655761911	2026-03-23 04:41:03.999238	2026-03-25 07:32:04.762238	\N	\N	\N	\N	\N	\N	$2a$12$ibrA9s9fdzW9DGn66zpm7uFsNpBat8WREnXYm/o63GnDeccgsulPm	\N	904, A block, Nester Raga Apartments, Mahadevapura, Bangalore 560048	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	ag50GLF28aW-Aipgp8ejmz89YUt_jLg02WCu2N3m4OI	2026-03-25 07:32:04.760871
487	Ajji	G	mamathanagaraju08@gmail.com	9739001874	2026-03-25 10:14:56.163746	2026-03-25 10:14:56.163746	\N	\N	\N	\N	\N	\N	$2a$12$rUKMyhjNoEYL.X2qZh8M8OYdlGrFPsdOwFlTXQqaf1BOGX9BW7Cca	\N		\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	\N	\N
481	raghunandan	kt	drwisedev@gmail.com	9844070041	2026-03-19 08:07:57.31055	2026-03-26 04:32:20.94922	\N	\N	\N	\N	\N	\N	$2a$12$gyqj7jB9ewkbR2pwgUS48erf/AkROt9Z/LOvPNzIYO5o9KF0Rg73m	\N	5 8th cross N.R Layout R.M Nagar	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	532cd3806192bd80d241829dc89e74a2574681e930b96d9cd4e4160672934e46	2026-03-26 04:38:33.855333
482	John	Doe	gepeucoubourou-9168@yopmail.com	7349673793	2026-03-21 07:05:43.706315	2026-03-21 07:05:43.706315	\N	\N	\N	\N	\N	\N	$2a$12$b11ijjC00wkGnr6d9vLJeuWTMrEJRZwzanI5zCP91gRvL1uEY9d5i	\N		\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	\N	\N
488	raghu	kt	raghubit040@gmail.com	9035378833	2026-03-27 15:04:43.94646	2026-03-27 15:04:43.94646	\N	\N	\N	\N	\N	\N	$2a$12$82om7QXn65cvoQC0HpLYh.kjSvJcom48TYEaqFVhpsgzTkCP0HzCy	\N		\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	\N	\N
483	Swapna	K	sapnasappu813@gmail.com	7019988524	2026-03-21 09:50:59.420494	2026-03-21 09:50:59.420494	\N	\N	\N	\N	\N	\N	$2a$12$C/BIvt8hurt.pTcVkqUd8OOmT0orz2D7GX6oZ.OSznbBAQ5uSRWMy	\N		\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	\N	\N
489	Sunil 	Cr	sunilkumar.blg6@gmail.com	9880624210	2026-03-28 17:48:01.414324	2026-03-28 17:48:01.414324	\N	\N	\N	\N	\N	\N	$2a$12$bhno6U/RxI0J6mm3uQR.N.qXqFNIEJ5Y/0hYH7Gjhp9uI445qF2p.	\N	DG63, D2 block, Ittina neela apartment, glass factory road, anantha nagara, Electronic city phase 2, Sarjapura, Anekal Taluka.	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	\N	\N
486	Payment	Test	paymenttest@test.com	9876543210	2026-03-25 07:01:01.958534	2026-03-29 01:39:46.934999	\N	\N	\N	\N	\N	\N	$2a$12$f7gdPNFLkUCwGETq64Hzuuj4B6ScGtek1ryPdt8vb9PkwmnVYItqO	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	\N	\N
\.


--
-- Data for Name: delivery_people; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.delivery_people (id, first_name, last_name, email, mobile, vehicle_type, vehicle_number, license_number, address, city, state, pincode, emergency_contact_name, emergency_contact_mobile, joining_date, salary, status, profile_picture, bank_name, account_no, ifsc_code, account_holder_name, delivery_areas, notes, created_at, updated_at, password_digest, auto_generated_password) FROM stdin;
17	Javeed	Patel	maralisanthe@gmail.com	917975918232	0	KA01HE1711	12345678	NR colony Bangalore	Bangalore	Karnataka	560004	marali santhe 	919035408833	2025-12-03	15000.0	t	\N					bangalore 		2026-03-20 07:59:01.645379	2026-03-20 07:59:01.645379	$2a$12$fQKLXUAsdXmubzS3QXLGv.oyF1LIonmfs8SD0pDCskzzyW2aFz9fi	\N
\.


--
-- Data for Name: delivery_rules; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.delivery_rules (id, product_id, rule_type, location_data, is_excluded, delivery_days, delivery_charge, created_at, updated_at) FROM stdin;
42	45	0	[]	f	7	0.00	2026-03-19 09:25:14.380198	2026-03-19 14:16:08.250853
37	40	0	[]	f	7	0.00	2026-03-19 09:11:09.334159	2026-03-19 14:18:47.724587
39	42	0	[]	f	7	0.00	2026-03-19 09:15:33.460407	2026-03-19 14:20:23.015878
35	38	0	[]	f	7	0.00	2026-03-19 08:58:29.728736	2026-03-19 14:25:37.333121
36	39	0	[]	f	7	0.00	2026-03-19 09:01:27.951028	2026-03-19 14:27:19.51386
43	46	0	[]	f	7	0.00	2026-03-19 09:30:21.404347	2026-03-19 14:30:18.719324
44	47	0	[]	f	7	0.00	2026-03-19 09:33:46.3973	2026-03-19 14:32:00.784716
45	48	0	[]	f	7	0.00	2026-03-19 09:35:13.537666	2026-03-19 14:33:31.185736
46	49	0	[]	f	7	0.00	2026-03-25 03:36:34.055139	2026-03-25 04:48:03.229601
47	50	0	[]	f	7	0.00	2026-03-29 05:32:37.859672	2026-03-29 05:32:37.859672
32	35	0	[]	f	7	0.00	2026-03-19 08:25:49.294029	2026-03-19 13:46:44.821282
33	36	0	[]	f	7	0.00	2026-03-19 08:34:02.666634	2026-03-19 13:48:05.117241
34	37	0	[]	f	7	0.00	2026-03-19 08:49:25.784459	2026-03-19 13:53:14.21838
38	41	0	[]	f	7	0.00	2026-03-19 09:13:09.575057	2026-03-19 14:09:41.870206
41	44	0	[]	f	7	0.00	2026-03-19 09:23:10.661685	2026-03-19 14:11:36.35594
40	43	0	[]	f	7	0.00	2026-03-19 09:18:09.79611	2026-03-19 14:13:29.675313
\.


--
-- Data for Name: device_tokens; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.device_tokens (id, customer_id, delivery_person_id, token, device_type, active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: franchises; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.franchises (id, name, email, mobile, contact_person_name, business_type, address, city, state, pincode, pan_no, gst_no, license_no, establishment_date, territory, franchise_fee, commission_percentage, status, notes, password_digest, auto_generated_password, longitude, latitude, whatsapp_number, profile_image, business_documents, created_at, updated_at, user_id) FROM stdin;
\.


--
-- Data for Name: invoice_items; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.invoice_items (id, invoice_id, milk_delivery_task_id, description, quantity, unit_price, total_amount, created_at, updated_at, product_id) FROM stdin;
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.invoices (id, invoice_number, payout_type, payout_id, total_amount, status, invoice_date, due_date, paid_at, created_at, updated_at, customer_id, payment_status, share_token, quick_invoice, paid_amount) FROM stdin;
\.


--
-- Data for Name: leads; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.leads (id, name, contact_number, email, current_stage, lead_source, created_at, updated_at, product_category, product_subcategory, customer_type, affiliate_id, is_direct, first_name, last_name, middle_name, company_name, gender, marital_status, pan_no, gst_no, height, weight, annual_income, business_job) FROM stdin;
\.


--
-- Data for Name: milk_delivery_tasks; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.milk_delivery_tasks (id, subscription_id, customer_id, product_id, quantity, unit, delivery_date, delivery_person_id, status, assigned_at, completed_at, delivery_notes, created_at, updated_at, invoiced, invoiced_at) FROM stdin;
\.


--
-- Data for Name: milk_subscriptions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.milk_subscriptions (id, customer_id, product_id, quantity, unit, start_date, end_date, delivery_time, delivery_pattern, specific_dates, total_amount, status, is_active, created_by, created_at, updated_at, delivery_person_id) FROM stdin;
\.


--
-- Data for Name: notes; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.notes (id, title, paid_to, amount, payment_method, reference_number, description, status, note_date, created_by_user_id, created_at, updated_at, paid_from, paid_to_category) FROM stdin;
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.notifications (id, customer_id, title, message, notification_type, data, read, read_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.order_items (id, order_id, product_id, quantity, price, total, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.orders (id, customer_id, user_id, order_number, order_date, status, payment_method, payment_status, subtotal, tax_amount, discount_amount, shipping_amount, total_amount, notes, order_items, customer_name, customer_email, customer_phone, delivery_address, tracking_number, delivered_at, created_at, updated_at, processing_notes, estimated_processing_time, processing_started_at, packed_by, package_weight, package_dimensions, packing_notes, packed_at, shipping_carrier, estimated_delivery_date, shipping_cost, shipping_notes, shipped_at, delivered_to, delivery_location, delivery_notes, cancelled_at, cancellation_reason, refund_method, refund_amount, cancellation_notes, invoice_generated, invoice_number, cash_received, change_amount, order_stage, booking_date, booking_id) FROM stdin;
\.


--
-- Data for Name: pending_amounts; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.pending_amounts (id, customer_id, amount, description, pending_date, status, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.permissions (id, name, resource, action, description, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: product_ratings; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.product_ratings (id, product_id, customer_id, user_id, rating, comment, status, reviewer_name, reviewer_email, verified_purchase, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: product_reviews; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.product_reviews (id, product_id, customer_id, user_id, rating, comment, reviewer_name, reviewer_email, status, verified_purchase, helpful_count, pros, cons, title, images_data, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.products (id, name, description, category_id, price, discount_price, stock, status, sku, weight, dimensions, meta_title, meta_description, tags, created_at, updated_at, discount_type, discount_value, original_price, discount_amount, is_discounted, gst_enabled, gst_percentage, cgst_percentage, sgst_percentage, igst_percentage, gst_amount, cgst_amount, sgst_amount, igst_amount, final_amount_with_gst, buying_price, yesterday_price, today_price, price_change_percentage, last_price_update, price_history, is_occasional_product, occasional_start_date, occasional_end_date, occasional_description, occasional_auto_hide, product_type, occasional_schedule_type, occasional_recurring_from_day, occasional_recurring_from_time, occasional_recurring_to_day, occasional_recurring_to_time, is_subscription_enabled, unit_type, minimum_stock_alert, default_selling_price, hsn_code, image_url, additional_images_urls, display_order, base_price_excluding_gst, r2_image_url, r2_additional_images) FROM stdin;
40	GROUNDNUT OIL [1LTR]	Experience the purity of Marali Santhe Wood Pressed Groundnut Oil, produced through a carefully controlled traditional process that ensures clean and consistent extraction. Free from chemicals, additives, and harmful contaminants, this oil retains its authentic taste and natural goodness.\r\n\r\nSourced directly from farms and processed with precision, it delivers rich flavor, nutritional value, and unmatched quality—making it a trusted choice for daily cooking.	14	345.00	\N	2	active	OIL058162	\N					2026-03-19 09:11:09.303212	2026-03-19 14:18:47.698323	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N	\N	345.00	250.00	345.00	345.00	0.00	2026-03-19 09:11:09.302943	[{"date":"2026-03-19","price":"345.0","timestamp":1773911469}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Liter	\N	\N	\N	products/product-temp-83daca59c366f761		\N	\N		
39	HONEY WILD [300GM]	Experience the true taste of nature with our raw honey, sourced directly from trusted farms and forests. This honey is completely unprocessed, ensuring that all its natural nutrients, enzymes, and rich flavor are preserved just as nature intended.\r\n\r\nFree from any form of adulteration, our honey contains no additives, no preservatives, and absolutely no added sugar. What you get is 100% pure honey, untouched and unfiltered, with its natural aroma, texture, and goodness intact.\r\n\r\nCarefully collected and minimally handled, this honey retains its authentic taste and health benefits, making it a perfect natural sweetener for your daily needs.	13	380.00	\N	5	active	NATE21547	\N					2026-03-19 09:01:27.91591	2026-03-19 14:27:19.483523	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	18.10	\N	\N	\N	380.00	195.00	380.00	380.00	0.00	2026-03-19 09:01:27.915658	[{"date":"2026-03-19","price":"380.0","timestamp":1773910887}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Kg	\N	\N	\N	products/product-temp-afa91f0185a16277		\N	361.9		
37	DESI BUTTER [500GM]	Indulge in the richness of Marali Santhe A2 Fresh Butter, crafted from high-quality milk sourced from indigenous cows. Made in small batches, our butter is fresh, natural, and full of authentic flavor, bringing you the taste of traditional homemade makkhan.\r\n\r\nPrepared with care and without any additives, this butter retains its natural aroma, soft texture, and wholesome goodness — perfect for everyday use and traditional recipes.\r\n\r\nPacked in eco-friendly, biodegradable packaging, we ensure not just purity in what you eat, but responsibility in how it’s delivered.	12	600.00	\N	6	active	DAIEF43F7	\N					2026-03-19 08:49:25.758241	2026-03-19 13:53:14.187043	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	28.57	\N	\N	\N	600.00	480.00	600.00	600.00	0.00	2026-03-19 08:49:25.757978	[{"date":"2026-03-19","price":"600.0","timestamp":1773910165}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Kg	\N	\N	\N	products/product-temp-d3529647965d4da3		\N	571.43		
42	COCONUT OIL [1LTR]	Marali Santhe Wood Pressed Coconut Oil is crafted using traditional extraction methods combined with precise milling to preserve its natural purity and aroma. Made from carefully sourced coconuts, this oil is free from harmful substances, additives, and contamination.\r\n\r\nWith its rich natural fragrance and smooth texture, it is perfect for cooking, sautéing, and traditional recipes. It also serves as a versatile oil for daily use, bringing authenticity, purity, and nourishment into your lifestyle.	14	650.00	\N	7	active	OIL16DE03	\N					2026-03-19 09:15:33.429197	2026-03-19 14:20:22.988153	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	30.95	\N	\N	\N	650.00	450.00	650.00	650.00	0.00	2026-03-19 09:15:33.42893	[{"date":"2026-03-19","price":"650.0","timestamp":1773911733}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Liter	\N	\N	\N	products/product-temp-8f3c981bdf9adb09		\N	619.05		
43	SESAME OIL [1LTR]	Marali Santhe Wood Pressed Sesame Oil is crafted using traditional extraction methods combined with precise milling to preserve its natural richness and purity. Made from farm-sourced sesame seeds, this oil is free from harmful substances, additives, and contamination.\r\n\r\nKnown for its distinct aroma and deep flavor, it enhances traditional dishes and everyday cooking. Carefully processed to retain its natural qualities, it brings authenticity, taste, and nourishment to your kitchen.	14	490.00	\N	0	active	OIL345526	\N					2026-03-19 09:18:09.767699	2026-03-19 14:13:29.644354	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	23.33	\N	\N	\N	490.00	360.00	490.00	490.00	0.00	2026-03-19 09:18:09.767433	[{"date":"2026-03-19","price":"490.0","timestamp":1773911889}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Liter	\N	\N	\N	products/product-temp-4d39ebc75ee49e62		\N	466.67		
45	SAFFLOWER OIL [1LTR]	Marali Santhe Wood Pressed Safflower Oil is produced through a refined traditional process that ensures clean and consistent extraction. Free from chemicals, additives, and harmful contaminants, this oil maintains its naturally light character and purity.\r\n\r\nSourced directly from farms and processed with precision, it delivers a smooth and clean cooking experience—making it an ideal choice for everyday use	14	530.00	\N	4	active	OILC25966	\N					2026-03-19 09:25:14.348315	2026-03-19 14:16:08.222553	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	25.24	\N	\N	\N	530.00	395.00	530.00	530.00	0.00	2026-03-19 09:25:14.348038	[{"date":"2026-03-19","price":"530.0","timestamp":1773912314}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Liter	\N	\N	\N	products/product-temp-202d1204e5679f80		\N	504.76		
36	DESI COW GHEE [225ML]	Experience purity the traditional way with Marali Santhe A2 Desi Cow Ghee, crafted using the time-honored Bilona method. This authentic process preserves the natural nutrients, aroma, and richness that modern methods often lose.\r\n\r\nOur ghee is made from fresh, cultured butter sourced from high-quality milk of indigenous cows. The butter is slowly churned and gently simmered in small batches to bring out the golden texture, grainy consistency, and rich aroma that define true desi ghee.\r\n\r\nEvery jar reflects our commitment to tradition, quality, and purity — delivering not just taste, but nourishment rooted in heritage.	12	350.00	\N	5	active	DAIE90911	\N					2026-03-19 08:34:02.625067	2026-03-19 13:48:05.087701	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	16.67	\N	\N	\N	350.00	250.00	350.00	350.00	0.00	2026-03-19 08:34:02.624833	[{"date":"2026-03-19","price":"350.0","timestamp":1773909242}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Liter	\N	\N	\N	products/product-temp-4a27681675e12237		\N	333.33		
44	MUSTARD OIL [1LTR]	Experience the bold character of Marali Santhe Wood Pressed Mustard Oil, produced through a refined traditional process that ensures clean and consistent extraction. Free from chemicals, additives, and harmful contaminants, this oil retains its natural pungency and richness.\r\n\r\nSourced directly from farms and processed with precision, it offers depth of flavor, purity, and reliability—perfect for traditional cooking and everyday use.	14	370.00	\N	5	active	OIL2FB4ED	\N					2026-03-19 09:23:10.632063	2026-03-19 14:11:28.201931	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	17.62	\N	\N	\N	370.00	275.00	370.00	370.00	0.00	2026-03-19 09:23:10.631858	[{"date":"2026-03-19","price":"370.0","timestamp":1773912190}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Liter	\N	\N	\N	products/product-temp-1512885373b596f8		\N	352.38		
46	RAJMUDI RICE [1KG]	Experience the legacy of traditional grains with Marali Santhe Rajamudi Rice—a heritage variety known for its rich character and cultural significance. Farm sourced and carefully handled to preserve its natural integrity, this rice remains free from harmful substances and excessive processing.\r\n\r\nWith its unique color, texture, and depth of flavor, Rajamudi Rice reflects purity, tradition, and mindful eating—bringing back the essence of authentic, wholesome food.	15	130.00	\N	22	active	GRAFA358B	\N					2026-03-19 09:30:21.373073	2026-03-19 14:30:18.673026	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	6.19	\N	\N	\N	130.00	83.00	130.00	130.00	0.00	2026-03-19 09:30:21.37285	[{"date":"2026-03-19","price":"130.0","timestamp":1773912621}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Kg	\N	\N	\N	products/product-temp-447efd9a2e6afc90		\N	123.81		
41	SUNFLOWER OIL [1LTR]	Marali Santhe Wood Pressed Sunflower Oil is produced through a refined traditional process that ensures clean and consistent extraction. Free from chemicals, additives, and harmful contaminants, this oil maintains its natural lightness and purity.\r\n\r\nSourced directly from farms and processed with precision, it delivers a smooth cooking experience with a clean finish—making it an ideal choice for modern and everyday cooking needs	14	350.00	\N	0	active	OIL642EB9	\N					2026-03-19 09:13:09.545141	2026-03-19 14:09:41.833902	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	16.67	\N	\N	\N	350.00	250.00	350.00	350.00	0.00	2026-03-19 09:13:09.544919	[{"date":"2026-03-19","price":"350.0","timestamp":1773911589}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Liter	\N	\N	\N	products/product-temp-0e5d0690afd68444		\N	333.33		
48	SONA MASURI RICE [5KG]	Marali Santhe Sona Masuri Rice is a popular everyday rice variety known for its light texture, subtle aroma, and versatility. Sourced directly from farms and carefully processed, it retains its natural qualities without exposure to harmful substances or unnecessary refinement.\r\n\r\nPerfect for daily cooking, this rice cooks soft and fluffy, making it ideal for a variety of dishes. With its balanced taste and purity, it brings consistency, quality, and comfort to your everyday meals.	15	600.00	570.00	5	active	GRA1E5641	\N					2026-03-19 09:35:13.505614	2026-03-19 14:33:31.155797	percentage	\N	\N	\N	t	t	5.00	\N	\N	\N	27.14	\N	\N	\N	570.00	360.00	600.00	600.00	0.00	2026-03-19 09:35:13.50536	[{"date":"2026-03-19","price":"600.0","timestamp":1773912913}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Kg	\N	\N	\N	products/product-temp-a72d95ec8a8e061d		\N	542.86		
47	SONA MASURI RICE [1KG]	Marali Santhe Sona Masuri Rice is a popular everyday rice variety known for its light texture, subtle aroma, and versatility. Sourced directly from farms and carefully processed, it retains its natural qualities without exposure to harmful substances or unnecessary refinement.\r\n\r\nPerfect for daily cooking, this rice cooks soft and fluffy, making it ideal for a variety of dishes. With its balanced taste and purity, it brings consistency, quality, and comfort to your everyday meals.	15	130.00	\N	16	active	GRA9F3769	\N					2026-03-19 09:33:46.36704	2026-03-19 14:32:00.757379	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	6.19	\N	\N	\N	130.00	68.00	130.00	130.00	0.00	2026-03-19 09:33:46.366803	[{"date":"2026-03-19","price":"130.0","timestamp":1773912826}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Kg	\N	\N	\N	products/product-temp-d185cec48ee0c9f7		\N	123.81		
49	Test	we	11	100.00	\N	309	active	23	\N					2026-03-25 03:36:33.683134	2026-03-25 04:48:02.974255	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	5.00	\N	\N	\N	100.00	12.00	100.00	100.00	0.00	2026-03-25 03:36:33.682656	[{"date":"2026-03-25","price":"100.0","timestamp":1774409793}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Kg	\N	\N	\N			\N	95.0	\N	\N
35	DESI COW GHEE [500ML]	Experience purity the traditional way with Marali Santhe A2 Desi Cow Ghee, crafted using the time-honored Bilona method. This authentic process preserves the natural nutrients, aroma, and richness that modern methods often lose.\r\n\r\nOur ghee is made from fresh, cultured butter sourced from high-quality milk of indigenous cows. The butter is slowly churned and gently simmered in small batches to bring out the golden texture, grainy consistency, and rich aroma that define true desi ghee.\r\n\r\nEvery jar reflects our commitment to tradition, quality, and purity — delivering not just taste, but nourishment rooted in heritage.	12	750.00	\N	1	active	DAI6D3E30	\N					2026-03-19 08:25:49.262541	2026-03-19 13:46:44.788954	percentage	\N	\N	\N	f	t	5.00	\N	\N	\N	35.71	\N	\N	\N	750.00	500.00	750.00	750.00	0.00	2026-03-19 08:25:49.262216	[{"date":"2026-03-19","price":"750.0","timestamp":1773908749}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Liter	\N	\N	\N	products/product-temp-66ccfd5c98557d3e		\N	714.29		
38	HONEY RAW [300GM]	Experience the true taste of nature with our raw honey, sourced directly from trusted farms and forests. This honey is completely unprocessed, ensuring that all its natural nutrients, enzymes, and rich flavor are preserved just as nature intended.\r\n\r\nFree from any form of adulteration, our honey contains no additives, no preservatives, and absolutely no added sugar. What you get is 100% pure honey, untouched and unfiltered, with its natural aroma, texture, and goodness intact.\r\n\r\nCarefully collected and minimally handled, this honey retains its authentic taste and health benefits, making it a perfect natural sweetener for your daily needs.	13	270.00	\N	0	active	NATB11DA3	\N					2026-03-19 08:58:29.700127	2026-03-19 14:25:37.304229	\N	\N	\N	\N	f	t	5.00	\N	\N	\N	12.86	\N	\N	\N	270.00	180.00	270.00	270.00	0.00	2026-03-19 08:58:29.699889	[{"date":"2026-03-19","price":"270.0","timestamp":1773910709}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Kg	\N	\N	\N	products/product-temp-b03032958a2f40c3		\N	257.14		
50	Test product	sd	11	1.00	\N	3	active	23sdsdsdss	\N					2026-03-29 05:32:37.587278	2026-03-29 05:32:37.587278	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N	\N	1.00	23.00	1.00	1.00	0.00	2026-03-29 05:32:37.587002	[{"date":"2026-03-29","price":"1.0","timestamp":1774762357}]	f	\N	\N	\N	t	Grocery			\N		\N	f	Kg	\N	\N	\N			\N	\N	\N	\N
\.


--
-- Data for Name: referrals; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.referrals (id, affiliate_id, referred_name, referred_mobile, referred_email, referral_date, status, notes, converted_at, customer_id, created_at, updated_at, referring_customer_id, referral_source) FROM stdin;
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.roles (id, name, description, status, permissions, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sale_items; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.sale_items (id, booking_id, product_id, stock_batch_id, quantity, selling_price, purchase_price, profit_amount, line_total, created_at, updated_at) FROM stdin;
1	91	41	48	1.0	350.0	250.0	100.0	350.0	2026-03-25 07:13:39.161428	2026-03-25 07:13:39.161428
2	91	49	58	3.0	100.0	12.0	264.0	300.0	2026-03-25 07:13:40.715216	2026-03-25 07:13:40.715216
3	91	47	54	1.0	130.0	68.0	62.0	130.0	2026-03-25 07:13:42.315825	2026-03-25 07:13:42.315825
4	92	35	43	1.0	750.0	500.0	250.0	750.0	2026-03-25 07:50:44.249167	2026-03-25 07:50:44.249167
5	93	35	43	1.0	750.0	500.0	250.0	750.0	2026-03-25 07:50:57.689838	2026-03-25 07:50:57.689838
6	94	35	43	2.0	750.0	500.0	500.0	1500.0	2026-03-26 03:34:19.837869	2026-03-26 03:34:19.837869
7	81	35	43	2.0	750.0	500.0	500.0	1500.0	2026-03-26 03:38:34.479238	2026-03-26 03:38:34.479238
8	95	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 04:41:58.819926	2026-03-26 04:41:58.819926
9	96	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 04:42:02.984925	2026-03-26 04:42:02.984925
10	97	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 04:42:05.008453	2026-03-26 04:42:05.008453
11	98	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 04:42:06.912385	2026-03-26 04:42:06.912385
12	99	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 04:42:40.137386	2026-03-26 04:42:40.137386
13	99	43	50	1.0	490.0	360.0	130.0	490.0	2026-03-26 04:42:40.333161	2026-03-26 04:42:40.333161
14	101	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 05:01:39.458557	2026-03-26 05:01:39.458557
15	101	43	50	1.0	490.0	360.0	130.0	490.0	2026-03-26 05:01:40.964505	2026-03-26 05:01:40.964505
16	102	35	60	1.0	750.0	600.0	150.0	750.0	2026-03-26 06:51:40.512567	2026-03-26 06:51:40.512567
17	105	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 07:25:39.569628	2026-03-26 07:25:39.569628
18	106	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 08:33:19.196775	2026-03-26 08:33:19.196775
19	107	49	58	2.0	100.0	12.0	176.0	200.0	2026-03-26 08:43:28.450674	2026-03-26 08:43:28.450674
20	108	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 08:47:58.218007	2026-03-26 08:47:58.218007
21	109	49	58	1.0	100.0	12.0	88.0	100.0	2026-03-26 10:20:03.758192	2026-03-26 10:20:03.758192
22	110	35	60	2.0	750.0	600.0	300.0	1500.0	2026-03-28 12:36:08.157741	2026-03-28 12:36:08.157741
23	111	35	60	2.0	750.0	600.0	300.0	1500.0	2026-03-28 12:36:25.852371	2026-03-28 12:36:25.852371
24	112	35	60	2.0	750.0	600.0	300.0	1500.0	2026-03-28 12:36:45.730328	2026-03-28 12:36:45.730328
25	125	50	62	1.0	1.0	23.0	-22.0	1.0	2026-03-29 06:54:04.005942	2026-03-29 06:54:04.005942
26	125	50	62	1.0	1.0	23.0	-22.0	1.0	2026-03-29 06:54:04.853281	2026-03-29 06:54:04.853281
27	126	50	62	1.0	1.0	23.0	-22.0	1.0	2026-03-29 07:04:51.65695	2026-03-29 07:04:51.65695
28	128	50	62	1.0	1.0	23.0	-22.0	1.0	2026-03-29 07:13:47.706769	2026-03-29 07:13:47.706769
29	129	50	62	1.0	1.0	23.0	-22.0	1.0	2026-03-29 10:04:24.1765	2026-03-29 10:04:24.1765
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.schema_migrations (version) FROM stdin;
0
20260107092810
20260107101240
20260107111549
20260107131159
20260107131309
20260107131913
20260107150605
20260107150728
20260107150805
20260107150814
20260107151651
20260107171920
20260108042049
20260108042658
20260108043706
20260108045016
20260108045914
20260108060039
20260108072509
20260108104259
20260108110047
20260108171419
20260109024857
20260111014913
20260111020543
20260111020547
20260111031353
20260111032424
20260111060641
20260111070348
20260111071020
20260111071120
20260111071219
20260111071659
20260111092557
20260111101523
20260111101527
20260111105247
20260208061341
20260208062719
20260208101409
20260208101558
20260208101609
20260208101620
20260208101643
20260208101648
20260208102424
20260208102434
20260208103030
20260208103125
20260208153931
20260209090000
20260209090001
20260211095237
20260212010028
20260212023145
20260212114420
1
20260212133027
20260213005145
20260214025047
20260216073135
20260217163319
20260218014142
20260218014153
20260218014204
20260218073032
20260218073033
20260218073034
20260218073035
20260218073036
20260218073037
20260218104948
20260218105107
20260218105116
20260218111202
20260218111627
20260218113731
20260219063828
20260219065729
20260219114349
20260219163202
20260219163237
20260219163249
20260219163301
20260220121130
20260220170323
20260221051144
20260221051526
20260221071051
20260222101845
20260222113448
20260223003701
20260223004840
20260223012155
20260223013159
20260223093122
20260223112829
20260223140936
20260223140939
20260225162412
20260226005401
20260227012037
20260227042837
20260302070828
20260303124807
20260303140745
20260304040431
20260304150744
20260305011138
20260305013049
20260305013057
20260306005034
20260306133011
20260307032837
20260308030449
20260308054700
20260318032032
20260318041321
20260319105840
20260324011944
\.


--
-- Data for Name: solid_cache_entries; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_cache_entries (id, key, value, created_at, key_hash, byte_size) FROM stdin;
\.


--
-- Data for Name: solid_queue_blocked_executions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_blocked_executions (id, job_id, queue_name, priority, concurrency_key, expires_at, created_at) FROM stdin;
\.


--
-- Data for Name: solid_queue_claimed_executions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_claimed_executions (id, job_id, process_id, created_at) FROM stdin;
\.


--
-- Data for Name: solid_queue_failed_executions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_failed_executions (id, job_id, error, created_at) FROM stdin;
\.


--
-- Data for Name: solid_queue_jobs; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_jobs (id, queue_name, class_name, arguments, priority, active_job_id, scheduled_at, finished_at, concurrency_key, created_at, updated_at) FROM stdin;
1	default	ActiveStorage::PurgeJob	{"job_class":"ActiveStorage::PurgeJob","job_id":"6e23288f-1632-4c68-842a-338ef76d4f1b","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/1"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-12T12:07:57.722857051Z","scheduled_at":"2026-02-12T12:07:57.722472853Z"}	0	6e23288f-1632-4c68-842a-338ef76d4f1b	2026-02-12 12:07:57.722472	\N	\N	2026-02-12 12:07:58.597033	2026-02-12 12:07:58.597033
2	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"60be65de-262d-4dbd-a55d-cbd554f0d94c","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/2"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-12T13:21:25.315101323Z","scheduled_at":"2026-02-12T13:21:25.314201655Z"}	0	60be65de-262d-4dbd-a55d-cbd554f0d94c	2026-02-12 13:21:25.314201	\N	\N	2026-02-12 13:21:25.87722	2026-02-12 13:21:25.87722
3	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"89855de3-34bd-46a3-b6da-e80825359da8","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/3"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-12T16:39:33.848379658Z","scheduled_at":"2026-02-12T16:39:33.847795998Z"}	0	89855de3-34bd-46a3-b6da-e80825359da8	2026-02-12 16:39:33.847795	\N	\N	2026-02-12 16:39:36.448794	2026-02-12 16:39:36.448794
4	default	ActiveStorage::PurgeJob	{"job_class":"ActiveStorage::PurgeJob","job_id":"ed7d0e25-8623-461d-8d08-7d0f4fecb369","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/3"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-12T16:43:19.465350484Z","scheduled_at":"2026-02-12T16:43:19.465113217Z"}	0	ed7d0e25-8623-461d-8d08-7d0f4fecb369	2026-02-12 16:43:19.465113	\N	\N	2026-02-12 16:43:19.465773	2026-02-12 16:43:19.465773
5	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"99639898-b8c9-419c-99fa-761214dcc7c8","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/4"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-12T16:43:20.443497958Z","scheduled_at":"2026-02-12T16:43:20.443370029Z"}	0	99639898-b8c9-419c-99fa-761214dcc7c8	2026-02-12 16:43:20.44337	\N	\N	2026-02-12 16:43:20.443884	2026-02-12 16:43:20.443884
6	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"c61ace8a-f368-42e7-8542-a8a4edb93fc8","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/5"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-12T16:45:25.189604937Z","scheduled_at":"2026-02-12T16:45:25.189416184Z"}	0	c61ace8a-f368-42e7-8542-a8a4edb93fc8	2026-02-12 16:45:25.189416	\N	\N	2026-02-12 16:45:25.190008	2026-02-12 16:45:25.190008
7	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"e5ee5f19-af29-4b1f-bd97-d6f3a7a8c352","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/6"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-13T05:51:25.110849051Z","scheduled_at":"2026-02-13T05:51:25.110299088Z"}	0	e5ee5f19-af29-4b1f-bd97-d6f3a7a8c352	2026-02-13 05:51:25.110299	\N	\N	2026-02-13 05:51:27.617643	2026-02-13 05:51:27.617643
8	default	ActiveStorage::PurgeJob	{"job_class":"ActiveStorage::PurgeJob","job_id":"92c464be-cfb8-424a-9405-5eb54be20c10","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/5"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-13T05:52:07.947848557Z","scheduled_at":"2026-02-13T05:52:07.947462818Z"}	0	92c464be-cfb8-424a-9405-5eb54be20c10	2026-02-13 05:52:07.947462	\N	\N	2026-02-13 05:52:10.513936	2026-02-13 05:52:10.513936
9	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"b890e8e2-667a-4697-ad5d-f81ef5e2e900","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/7"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"UTC","enqueued_at":"2026-02-13T05:52:11.920236510Z","scheduled_at":"2026-02-13T05:52:11.920077446Z"}	0	b890e8e2-667a-4697-ad5d-f81ef5e2e900	2026-02-13 05:52:11.920077	\N	\N	2026-02-13 05:52:11.920643	2026-02-13 05:52:11.920643
10	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"f50176f0-d090-4d1c-89a8-b449c18abcac","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/8"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T11:41:10.013383748Z","scheduled_at":"2026-02-16T11:41:10.012471817Z"}	0	f50176f0-d090-4d1c-89a8-b449c18abcac	2026-02-16 11:41:10.012471	\N	\N	2026-02-16 11:41:10.568931	2026-02-16 11:41:10.568931
11	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"456ccfd9-642e-4cfe-87a5-b45da6074bb1","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/9"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T15:33:45.707208019Z","scheduled_at":"2026-02-16T15:33:45.706707231Z"}	0	456ccfd9-642e-4cfe-87a5-b45da6074bb1	2026-02-16 15:33:45.706707	\N	\N	2026-02-16 15:33:48.323511	2026-02-16 15:33:48.323511
12	default	ActiveStorage::PurgeJob	{"job_class":"ActiveStorage::PurgeJob","job_id":"7864fab5-6375-4d22-acd2-efd284bcc525","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/6"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T15:36:49.657321108Z","scheduled_at":"2026-02-16T15:36:49.656669795Z"}	0	7864fab5-6375-4d22-acd2-efd284bcc525	2026-02-16 15:36:49.656669	\N	\N	2026-02-16 15:36:52.194294	2026-02-16 15:36:52.194294
13	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"82d1ff4b-ea1f-45f3-928f-bf3cebb9602f","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/10"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T15:36:53.673805268Z","scheduled_at":"2026-02-16T15:36:53.673583730Z"}	0	82d1ff4b-ea1f-45f3-928f-bf3cebb9602f	2026-02-16 15:36:53.673583	\N	\N	2026-02-16 15:36:53.674247	2026-02-16 15:36:53.674247
14	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"ff0b07bc-96b4-43b6-a00f-b04d9aff7e6e","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/11"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T15:40:01.260636627Z","scheduled_at":"2026-02-16T15:40:01.260445581Z"}	0	ff0b07bc-96b4-43b6-a00f-b04d9aff7e6e	2026-02-16 15:40:01.260445	\N	\N	2026-02-16 15:40:01.2613	2026-02-16 15:40:01.2613
15	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"1427b853-48d9-4ce7-8233-bc4268f428f7","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/12"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T15:43:43.614356050Z","scheduled_at":"2026-02-16T15:43:43.614114361Z"}	0	1427b853-48d9-4ce7-8233-bc4268f428f7	2026-02-16 15:43:43.614114	\N	\N	2026-02-16 15:43:43.614745	2026-02-16 15:43:43.614745
16	default	ActiveStorage::PurgeJob	{"job_class":"ActiveStorage::PurgeJob","job_id":"0710aca2-2e3a-44db-b281-424efe830868","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/2"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T15:53:15.246650294Z","scheduled_at":"2026-02-16T15:53:15.246464197Z"}	0	0710aca2-2e3a-44db-b281-424efe830868	2026-02-16 15:53:15.246464	\N	\N	2026-02-16 15:53:15.24743	2026-02-16 15:53:15.24743
17	default	ActiveStorage::PurgeJob	{"job_class":"ActiveStorage::PurgeJob","job_id":"a561657c-fb93-4c3c-9e20-cb0f9d43e5e3","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/7"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T15:53:43.174932856Z","scheduled_at":"2026-02-16T15:53:43.174717999Z"}	0	a561657c-fb93-4c3c-9e20-cb0f9d43e5e3	2026-02-16 15:53:43.174717	\N	\N	2026-02-16 15:53:43.17539	2026-02-16 15:53:43.17539
18	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"c56c58a2-39f2-4791-89ed-c7e18bc85049","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/13"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-16T15:57:33.581977091Z","scheduled_at":"2026-02-16T15:57:33.581778565Z"}	0	c56c58a2-39f2-4791-89ed-c7e18bc85049	2026-02-16 15:57:33.581778	\N	\N	2026-02-16 15:57:33.582414	2026-02-16 15:57:33.582414
19	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"37d3121b-a976-487c-ba07-49b2c7050b13","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/14"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-17T11:36:35.185074548Z","scheduled_at":"2026-02-17T11:36:35.184661547Z"}	0	37d3121b-a976-487c-ba07-49b2c7050b13	2026-02-17 11:36:35.184661	\N	\N	2026-02-17 11:36:37.932016	2026-02-17 11:36:37.932016
20	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"d8a483e3-adf1-41d9-81c5-a51f71de5664","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/15"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-21T10:11:28.515351286Z","scheduled_at":"2026-02-21T10:11:28.515018278Z"}	0	d8a483e3-adf1-41d9-81c5-a51f71de5664	2026-02-21 10:11:28.515018	\N	\N	2026-02-21 10:11:31.045528	2026-02-21 10:11:31.045528
21	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"207f1716-cc46-434e-8aa8-ea8898ef2d61","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/16"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-21T10:13:49.920534157Z","scheduled_at":"2026-02-21T10:13:49.920203919Z"}	0	207f1716-cc46-434e-8aa8-ea8898ef2d61	2026-02-21 10:13:49.920203	\N	\N	2026-02-21 10:13:52.322138	2026-02-21 10:13:52.322138
22	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"2830261b-bed7-472c-9dc6-7ea86aa4f2c1","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/17"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-21T10:15:08.320345478Z","scheduled_at":"2026-02-21T10:15:08.320170214Z"}	0	2830261b-bed7-472c-9dc6-7ea86aa4f2c1	2026-02-21 10:15:08.32017	\N	\N	2026-02-21 10:15:08.320723	2026-02-21 10:15:08.320723
23	default	ActiveStorage::PurgeJob	{"job_class":"ActiveStorage::PurgeJob","job_id":"d7f06716-edab-4e85-bb5f-d88cee3ff977","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/17"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-21T10:15:40.854595805Z","scheduled_at":"2026-02-21T10:15:40.854422160Z"}	0	d7f06716-edab-4e85-bb5f-d88cee3ff977	2026-02-21 10:15:40.854422	\N	\N	2026-02-21 10:15:40.854968	2026-02-21 10:15:40.854968
24	default	ImportMasterSubscriptionJob	{"job_class":"ImportMasterSubscriptionJob","job_id":"f7ad328b-71e3-44f3-8743-1c42d4a2ef98","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[2,2026],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-21T12:06:20.100626588Z","scheduled_at":"2026-02-21T12:06:20.096576234Z"}	0	f7ad328b-71e3-44f3-8743-1c42d4a2ef98	2026-02-21 12:06:20.096576	\N	\N	2026-02-21 12:06:20.717464	2026-02-21 12:06:20.717464
25	default	ImportMasterSubscriptionJob	{"job_class":"ImportMasterSubscriptionJob","job_id":"6b384f9d-b54b-4cea-afed-cd53b1496ad8","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[2,2026],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-21T12:10:52.551623352Z","scheduled_at":"2026-02-21T12:10:52.551484474Z"}	0	6b384f9d-b54b-4cea-afed-cd53b1496ad8	2026-02-21 12:10:52.551484	\N	\N	2026-02-21 12:10:53.090857	2026-02-21 12:10:53.090857
26	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"60e9eec0-7d07-404a-a755-7e789248e1de","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/18"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-21T12:14:16.008162025Z","scheduled_at":"2026-02-21T12:14:16.007946450Z"}	0	60e9eec0-7d07-404a-a755-7e789248e1de	2026-02-21 12:14:16.007946	\N	\N	2026-02-21 12:14:16.53278	2026-02-21 12:14:16.53278
27	default	ImportMasterSubscriptionJob	{"job_class":"ImportMasterSubscriptionJob","job_id":"da4109e5-cdae-4238-81ac-d9fda8f05331","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[2,2026],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-21T15:40:33.513742572Z","scheduled_at":"2026-02-21T15:40:33.513695409Z"}	0	da4109e5-cdae-4238-81ac-d9fda8f05331	2026-02-21 15:40:33.513695	\N	\N	2026-02-21 15:40:34.12814	2026-02-21 15:40:34.12814
28	default	ImportMasterSubscriptionJob	{"job_class":"ImportMasterSubscriptionJob","job_id":"6d5235ed-99d9-49c8-8907-01762b90f4ac","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[2,2026],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-22T10:08:55.666369836Z","scheduled_at":"2026-02-22T10:08:55.665408706Z"}	0	6d5235ed-99d9-49c8-8907-01762b90f4ac	2026-02-22 10:08:55.665408	\N	\N	2026-02-22 10:08:56.209446	2026-02-22 10:08:56.209446
29	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"9453dffb-868b-4482-aed9-b3223892157d","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/19"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-23T12:37:56.820662923Z","scheduled_at":"2026-02-23T12:37:56.820147142Z"}	0	9453dffb-868b-4482-aed9-b3223892157d	2026-02-23 12:37:56.820147	\N	\N	2026-02-23 12:37:59.232192	2026-02-23 12:37:59.232192
30	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"0d31db1b-b8a4-405f-9a02-50e2d445c468","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/20"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-23T12:38:00.616603331Z","scheduled_at":"2026-02-23T12:38:00.616397325Z"}	0	0d31db1b-b8a4-405f-9a02-50e2d445c468	2026-02-23 12:38:00.616397	\N	\N	2026-02-23 12:38:00.617011	2026-02-23 12:38:00.617011
31	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"2d15cbf0-f9db-4078-afe8-e73d7751115b","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/21"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-24T01:34:56.491290297Z","scheduled_at":"2026-02-24T01:34:56.490237963Z"}	0	2d15cbf0-f9db-4078-afe8-e73d7751115b	2026-02-24 01:34:56.490237	\N	\N	2026-02-24 01:34:57.060309	2026-02-24 01:34:57.060309
32	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"67334cfd-0a5a-4734-88ea-6d86157cebb3","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/22"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-24T03:43:14.638157906Z","scheduled_at":"2026-02-24T03:43:14.637799885Z"}	0	67334cfd-0a5a-4734-88ea-6d86157cebb3	2026-02-24 03:43:14.637799	\N	\N	2026-02-24 03:43:17.111964	2026-02-24 03:43:17.111964
33	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"75c04e6e-1148-40b7-a1ed-075c1661e52e","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/23"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-24T03:43:46.275943379Z","scheduled_at":"2026-02-24T03:43:46.275723386Z"}	0	75c04e6e-1148-40b7-a1ed-075c1661e52e	2026-02-24 03:43:46.275723	\N	\N	2026-02-24 03:43:46.276401	2026-02-24 03:43:46.276401
34	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"aeee57f2-ad1e-4289-8d29-c59a7df7837f","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/24"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-24T03:44:11.235329178Z","scheduled_at":"2026-02-24T03:44:11.235143437Z"}	0	aeee57f2-ad1e-4289-8d29-c59a7df7837f	2026-02-24 03:44:11.235143	\N	\N	2026-02-24 03:44:11.235808	2026-02-24 03:44:11.235808
35	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"e621030c-cf7a-41bc-a3cd-3786791044a3","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/25"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-02-27T00:42:19.326259178Z","scheduled_at":"2026-02-27T00:42:19.323683818Z"}	0	e621030c-cf7a-41bc-a3cd-3786791044a3	2026-02-27 00:42:19.323683	\N	\N	2026-02-27 00:42:19.954412	2026-02-27 00:42:19.954412
36	default	ActiveStorage::AnalyzeJob	{"job_class":"ActiveStorage::AnalyzeJob","job_id":"d3277748-0b43-4b29-b6e0-ea4947b7bb14","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/26"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-03-04T06:38:37.543931263Z","scheduled_at":"2026-03-04T06:38:37.543606849Z"}	0	d3277748-0b43-4b29-b6e0-ea4947b7bb14	2026-03-04 06:38:37.543606	\N	\N	2026-03-04 06:38:37.663663	2026-03-04 06:38:37.663663
37	default	ActiveStorage::PurgeJob	{"job_class":"ActiveStorage::PurgeJob","job_id":"ea4bf03e-29d5-4105-bbc0-8cdbf51db12f","provider_job_id":null,"queue_name":"default","priority":null,"arguments":[{"_aj_globalid":"gid://demo-farm-admin/ActiveStorage::Blob/22"}],"executions":0,"exception_executions":{},"locale":"en","timezone":"Asia/Kolkata","enqueued_at":"2026-03-18T10:57:27.447716270Z","scheduled_at":"2026-03-18T10:57:27.446225939Z"}	0	ea4bf03e-29d5-4105-bbc0-8cdbf51db12f	2026-03-18 10:57:27.446225	\N	\N	2026-03-18 10:57:28.005584	2026-03-18 10:57:28.005584
\.


--
-- Data for Name: solid_queue_pauses; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_pauses (id, queue_name, created_at) FROM stdin;
\.


--
-- Data for Name: solid_queue_processes; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_processes (id, kind, last_heartbeat_at, supervisor_id, pid, hostname, metadata, created_at, name) FROM stdin;
\.


--
-- Data for Name: solid_queue_ready_executions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_ready_executions (id, job_id, queue_name, priority, created_at) FROM stdin;
1	1	default	0	2026-02-12 12:08:00.659859
2	2	default	0	2026-02-12 13:21:27.640663
3	3	default	0	2026-02-12 16:39:37.679176
4	4	default	0	2026-02-12 16:43:19.969805
5	5	default	0	2026-02-12 16:43:20.94988
6	6	default	0	2026-02-12 16:45:25.693479
7	7	default	0	2026-02-13 05:51:28.627623
8	8	default	0	2026-02-13 05:52:11.540424
9	9	default	0	2026-02-13 05:52:12.424767
10	10	default	0	2026-02-16 11:41:12.278278
11	11	default	0	2026-02-16 15:33:49.423897
12	12	default	0	2026-02-16 15:36:53.268588
13	13	default	0	2026-02-16 15:36:54.199201
14	14	default	0	2026-02-16 15:40:04.659369
15	15	default	0	2026-02-16 15:43:44.121434
16	16	default	0	2026-02-16 15:53:19.14923
17	17	default	0	2026-02-16 15:53:43.70142
18	18	default	0	2026-02-16 15:57:34.091297
19	19	default	0	2026-02-17 11:36:38.978225
20	20	default	0	2026-02-21 10:11:32.011118
21	21	default	0	2026-02-21 10:13:53.303348
22	22	default	0	2026-02-21 10:15:08.798475
23	23	default	0	2026-02-21 10:15:41.331665
24	24	default	0	2026-02-21 12:06:22.503679
25	25	default	0	2026-02-21 12:10:54.802315
26	26	default	0	2026-02-21 12:14:18.105218
27	27	default	0	2026-02-21 15:40:36.102443
28	28	default	0	2026-02-22 10:08:57.895861
29	29	default	0	2026-02-23 12:38:00.248349
30	30	default	0	2026-02-23 12:38:01.104664
31	31	default	0	2026-02-24 01:34:58.817153
32	32	default	0	2026-02-24 03:43:18.089017
33	33	default	0	2026-02-24 03:43:46.756886
34	34	default	0	2026-02-24 03:44:11.717307
35	35	default	0	2026-02-27 00:42:21.668974
36	36	default	0	2026-03-04 06:38:37.748088
37	37	default	0	2026-03-18 10:57:29.689868
\.


--
-- Data for Name: solid_queue_recurring_executions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_recurring_executions (id, job_id, task_key, run_at, created_at) FROM stdin;
\.


--
-- Data for Name: solid_queue_recurring_tasks; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_recurring_tasks (id, key, schedule, command, class_name, arguments, queue_name, priority, static, description, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: solid_queue_scheduled_executions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_scheduled_executions (id, job_id, queue_name, priority, scheduled_at, created_at) FROM stdin;
\.


--
-- Data for Name: solid_queue_semaphores; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.solid_queue_semaphores (id, key, value, expires_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: stock_batches; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.stock_batches (id, product_id, vendor_id, vendor_purchase_id, quantity_purchased, quantity_remaining, purchase_price, selling_price, batch_date, status, created_at, updated_at) FROM stdin;
60	35	11	\N	10.0	1.0	600.0	750.0	2026-03-26	active	2026-03-26 06:50:33.860032	2026-03-28 12:36:44.826579
54	47	11	\N	25.0	16.0	68.0	130.0	2026-03-19	active	2026-03-19 09:33:46.519679	2026-03-29 04:13:25.553437
43	35	11	\N	10.0	0.0	500.0	750.0	2026-03-19	exhausted	2026-03-19 08:25:49.698752	2026-03-26 03:38:32.405987
58	49	11	\N	345.0	309.0	12.0	100.0	2026-03-25	active	2026-03-25 04:48:04.520486	2026-03-29 05:33:24.512789
48	41	11	\N	5.0	0.0	250.0	350.0	2026-03-19	exhausted	2026-03-19 09:13:09.708624	2026-03-26 04:46:31.021034
50	43	11	\N	5.0	0.0	360.0	490.0	2026-03-19	exhausted	2026-03-19 09:18:09.882759	2026-03-26 05:01:39.712018
59	37	11	11	2.0	2.0	23.0	455.0	2026-03-26	active	2026-03-26 06:45:49.237053	2026-03-26 06:45:49.237053
46	38	11	\N	5.0	0.0	180.0	270.0	2026-03-19	exhausted	2026-03-19 09:01:53.798047	2026-03-29 10:07:20.080285
61	42	11	12	3.0	3.0	4.0	344.0	2026-03-26	active	2026-03-26 07:19:50.520941	2026-03-26 07:19:50.520941
47	40	11	\N	5.0	2.0	250.0	345.0	2026-03-19	active	2026-03-19 09:11:09.452743	2026-03-29 10:17:30.533797
52	45	11	\N	5.0	4.0	395.0	530.0	2026-03-19	active	2026-03-19 09:25:14.473924	2026-03-29 10:18:10.072283
45	39	11	\N	5.0	5.0	195.0	380.0	2026-03-19	active	2026-03-19 09:01:28.089076	2026-03-19 09:01:28.089076
51	44	11	\N	5.0	5.0	275.0	370.0	2026-03-19	active	2026-03-19 09:23:10.747793	2026-03-19 09:23:10.747793
55	48	11	\N	5.0	5.0	360.0	600.0	2026-03-19	active	2026-03-19 09:35:13.633483	2026-03-19 09:35:13.633483
56	36	11	\N	5.0	5.0	250.0	350.0	2026-03-19	active	2026-03-19 09:36:02.599539	2026-03-19 09:36:02.599539
49	42	11	\N	5.0	4.0	450.0	650.0	2026-03-19	active	2026-03-19 09:15:33.545935	2026-03-21 07:07:02.168938
44	37	11	\N	5.0	4.0	480.0	600.0	2026-03-19	active	2026-03-19 08:49:25.992492	2026-03-21 07:08:58.626546
53	46	11	\N	25.0	22.0	83.0	130.0	2026-03-19	active	2026-03-19 09:30:21.49213	2026-03-25 04:23:02.373186
62	50	11	\N	23.0	3.0	23.0	1.0	2026-03-29	active	2026-03-29 05:32:39.644243	2026-03-29 10:41:18.987503
57	49	11	\N	2.0	0.0	12.0	100.0	2026-03-25	exhausted	2026-03-25 03:36:41.323722	2026-03-25 04:33:56.826277
\.


--
-- Data for Name: stock_movements; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.stock_movements (id, product_id, reference_type, reference_id, movement_type, quantity, stock_before, stock_after, notes, created_at, updated_at) FROM stdin;
140	35	adjustment	\N	added	10.00	0.00	10.00	Initial stock when product was created	2026-03-19 08:25:49.390745	2026-03-19 08:25:49.390745
141	37	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 08:49:25.881824	2026-03-19 08:49:25.881824
142	39	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 09:01:27.983037	2026-03-19 09:01:27.983037
143	40	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 09:11:09.365051	2026-03-19 09:11:09.365051
144	41	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 09:13:09.60796	2026-03-19 09:13:09.60796
145	42	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 09:15:33.489593	2026-03-19 09:15:33.489593
146	43	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 09:18:09.825117	2026-03-19 09:18:09.825117
147	44	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 09:23:10.690702	2026-03-19 09:23:10.690702
148	45	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 09:25:14.410414	2026-03-19 09:25:14.410414
149	46	adjustment	\N	added	25.00	0.00	25.00	Initial stock when product was created	2026-03-19 09:30:21.434377	2026-03-19 09:30:21.434377
150	47	adjustment	\N	added	25.00	0.00	25.00	Initial stock when product was created	2026-03-19 09:33:46.427725	2026-03-19 09:33:46.427725
151	48	adjustment	\N	added	5.00	0.00	5.00	Initial stock when product was created	2026-03-19 09:35:13.571858	2026-03-19 09:35:13.571858
152	41	booking	75	consumed	-2.00	5.00	3.00	Stock consumed for booking item: SUNFLOWER OIL [1LTR] (Qty: 2.0)	2026-03-19 09:39:03.382255	2026-03-19 09:39:03.382255
153	42	booking	76	consumed	-1.00	5.00	4.00	Stock consumed for booking item: COCONUT OIL [1LTR] (Qty: 1.0)	2026-03-21 07:07:02.358702	2026-03-21 07:07:02.358702
154	37	booking	77	consumed	-1.00	5.00	4.00	Stock consumed for booking item: DESI BUTTER [500GM] (Qty: 1.0)	2026-03-21 07:08:58.750817	2026-03-21 07:08:58.750817
155	38	booking	78	consumed	-1.00	5.00	4.00	Stock consumed for booking item: HONEY RAW [300GM] (Qty: 1.0)	2026-03-23 04:42:27.071879	2026-03-23 04:42:27.071879
156	35	booking	79	consumed	-1.00	10.00	9.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 1.0)	2026-03-24 03:55:33.411498	2026-03-24 03:55:33.411498
157	46	booking	80	consumed	-2.00	25.00	23.00	Stock consumed for booking item: RAJMUDI RICE [1KG] (Qty: 2.0)	2026-03-24 04:29:54.611463	2026-03-24 04:29:54.611463
158	47	booking	80	consumed	-1.00	25.00	24.00	Stock consumed for booking item: SONA MASURI RICE [1KG] (Qty: 1.0)	2026-03-24 04:30:02.814898	2026-03-24 04:30:02.814898
159	35	booking	81	consumed	-2.00	9.00	7.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-24 10:58:30.744432	2026-03-24 10:58:30.744432
160	35	booking	82	consumed	-2.00	7.00	5.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-24 10:59:27.483768	2026-03-24 10:59:27.483768
161	35	booking	83	consumed	-2.00	5.00	3.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-24 11:00:39.036932	2026-03-24 11:00:39.036932
162	35	booking	84	consumed	-2.00	3.00	1.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-24 11:01:13.786423	2026-03-24 11:01:13.786423
163	47	booking	85	consumed	-3.00	24.00	21.00	Stock consumed for booking item: SONA MASURI RICE [1KG] (Qty: 3.0)	2026-03-25 03:25:58.453895	2026-03-25 03:25:58.453895
164	49	adjustment	\N	added	2.00	0.00	2.00	Initial stock when product was created	2026-03-25 03:36:37.929045	2026-03-25 03:36:37.929045
165	46	booking	86	consumed	-1.00	23.00	22.00	Stock consumed for booking item: RAJMUDI RICE [1KG] (Qty: 1.0)	2026-03-25 04:23:09.250991	2026-03-25 04:23:09.250991
166	49	booking	87	consumed	-1.00	2.00	1.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-25 04:28:03.346643	2026-03-25 04:28:03.346643
167	49	booking	88	consumed	-1.00	1.00	0.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-25 04:33:58.366921	2026-03-25 04:33:58.366921
168	49	booking	89	consumed	-1.00	345.00	344.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-25 06:48:42.425557	2026-03-25 06:48:42.425557
169	35	booking	90	consumed	-1.00	1.00	0.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 1.0)	2026-03-25 07:07:18.28248	2026-03-25 07:07:18.28248
170	41	booking	91	consumed	-1.00	3.00	2.00	Stock consumed for booking item: SUNFLOWER OIL [1LTR] (Qty: 1.0)	2026-03-25 07:13:24.454315	2026-03-25 07:13:24.454315
171	49	booking	91	consumed	-3.00	344.00	341.00	Stock consumed for booking item: Test (Qty: 3.0)	2026-03-25 07:13:26.758247	2026-03-25 07:13:26.758247
172	47	booking	91	consumed	-1.00	21.00	20.00	Stock consumed for booking item: SONA MASURI RICE [1KG] (Qty: 1.0)	2026-03-25 07:13:29.163973	2026-03-25 07:13:29.163973
173	35	booking	92	consumed	-1.00	10.00	9.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 1.0)	2026-03-25 07:50:32.88642	2026-03-25 07:50:32.88642
174	35	booking	93	consumed	-1.00	8.00	7.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 1.0)	2026-03-25 07:50:51.300155	2026-03-25 07:50:51.300155
175	35	booking	94	consumed	-2.00	6.00	4.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-26 03:34:11.594613	2026-03-26 03:34:11.594613
176	49	booking	95	consumed	-1.00	338.00	337.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 04:41:57.595673	2026-03-26 04:41:57.595673
177	49	booking	96	consumed	-1.00	336.00	335.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 04:42:01.807732	2026-03-26 04:42:01.807732
178	49	booking	97	consumed	-1.00	336.00	335.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 04:42:04.400761	2026-03-26 04:42:04.400761
179	49	booking	98	consumed	-1.00	334.00	333.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 04:42:06.411509	2026-03-26 04:42:06.411509
180	49	booking	99	consumed	-1.00	332.00	331.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 04:42:39.206216	2026-03-26 04:42:39.206216
181	43	booking	99	consumed	-1.00	5.00	4.00	Stock consumed for booking item: SESAME OIL [1LTR] (Qty: 1.0)	2026-03-26 04:42:39.495944	2026-03-26 04:42:39.495944
182	41	booking	100	consumed	-1.00	1.00	0.00	Stock consumed for booking item: SUNFLOWER OIL [1LTR] (Qty: 1.0)	2026-03-26 04:46:37.574125	2026-03-26 04:46:37.574125
183	49	booking	100	consumed	-4.00	330.00	326.00	Stock consumed for booking item: Test (Qty: 4.0)	2026-03-26 04:46:39.948148	2026-03-26 04:46:39.948148
184	43	booking	100	consumed	-1.00	3.00	2.00	Stock consumed for booking item: SESAME OIL [1LTR] (Qty: 1.0)	2026-03-26 04:46:42.234068	2026-03-26 04:46:42.234068
185	49	booking	101	consumed	-1.00	326.00	325.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 05:01:29.142303	2026-03-26 05:01:29.142303
186	43	booking	101	consumed	-1.00	2.00	1.00	Stock consumed for booking item: SESAME OIL [1LTR] (Qty: 1.0)	2026-03-26 05:01:31.41463	2026-03-26 05:01:31.41463
187	37	vendor_purchase	11	added	2.00	4.00	6.00	Stock added from vendor purchase: VP000011 - DESI BUTTER [500GM] (Qty: 2.0)	2026-03-26 06:45:52.612587	2026-03-26 06:45:52.612587
188	35	booking	102	consumed	-1.00	10.00	9.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 1.0)	2026-03-26 06:51:15.737641	2026-03-26 06:51:15.737641
189	35	booking	103	consumed	-1.00	8.00	7.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 1.0)	2026-03-26 06:52:59.017429	2026-03-26 06:52:59.017429
190	49	booking	104	consumed	-1.00	324.00	323.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 06:56:50.688144	2026-03-26 06:56:50.688144
191	42	vendor_purchase	12	added	3.00	4.00	7.00	Stock added from vendor purchase: VP000012 - COCONUT OIL [1LTR] (Qty: 3.0)	2026-03-26 07:19:54.738409	2026-03-26 07:19:54.738409
192	49	booking	105	consumed	-1.00	323.00	322.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 07:25:22.008248	2026-03-26 07:25:22.008248
193	49	booking	106	consumed	-1.00	321.00	320.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 08:33:08.552565	2026-03-26 08:33:08.552565
194	49	booking	107	consumed	-2.00	319.00	317.00	Stock consumed for booking item: Test (Qty: 2.0)	2026-03-26 08:43:18.666708	2026-03-26 08:43:18.666708
195	49	booking	108	consumed	-1.00	315.00	314.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 08:47:49.909969	2026-03-26 08:47:49.909969
196	49	booking	109	consumed	-1.00	313.00	312.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-26 10:19:55.220671	2026-03-26 10:19:55.220671
197	35	booking	110	consumed	-2.00	7.00	5.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-28 12:35:50.774179	2026-03-28 12:35:50.774179
198	35	booking	111	consumed	-2.00	7.00	5.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-28 12:36:19.893983	2026-03-28 12:36:19.893983
199	35	booking	112	consumed	-2.00	7.00	5.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-28 12:36:39.723851	2026-03-28 12:36:39.723851
200	35	booking	113	consumed	-2.00	3.00	1.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-28 12:37:01.269171	2026-03-28 12:37:01.269171
201	35	booking	114	consumed	-2.00	3.00	1.00	Stock consumed for booking item: DESI COW GHEE [500ML] (Qty: 2.0)	2026-03-28 12:37:15.897914	2026-03-28 12:37:15.897914
202	47	booking	115	consumed	-1.00	19.00	18.00	Stock consumed for booking item: SONA MASURI RICE [1KG] (Qty: 1.0)	2026-03-29 01:44:56.284816	2026-03-29 01:44:56.284816
203	49	booking	115	consumed	-1.00	311.00	310.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-29 01:45:03.791584	2026-03-29 01:45:03.791584
204	38	booking	116	consumed	-1.00	4.00	3.00	Stock consumed for booking item: HONEY RAW [300GM] (Qty: 1.0)	2026-03-29 04:02:07.509346	2026-03-29 04:02:07.509346
205	47	booking	117	consumed	-1.00	18.00	17.00	Stock consumed for booking item: SONA MASURI RICE [1KG] (Qty: 1.0)	2026-03-29 04:08:25.945635	2026-03-29 04:08:25.945635
206	47	booking	118	consumed	-1.00	17.00	16.00	Stock consumed for booking item: SONA MASURI RICE [1KG] (Qty: 1.0)	2026-03-29 04:13:34.405025	2026-03-29 04:13:34.405025
207	38	booking	119	consumed	-1.00	3.00	2.00	Stock consumed for booking item: HONEY RAW [300GM] (Qty: 1.0)	2026-03-29 05:29:04.548793	2026-03-29 05:29:04.548793
208	50	adjustment	\N	added	23.00	0.00	23.00	Initial stock when product was created	2026-03-29 05:32:38.883842	2026-03-29 05:32:38.883842
209	49	booking	120	consumed	-1.00	310.00	309.00	Stock consumed for booking item: Test (Qty: 1.0)	2026-03-29 05:33:25.719332	2026-03-29 05:33:25.719332
210	50	booking	121	consumed	-1.00	23.00	22.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 05:38:51.441626	2026-03-29 05:38:51.441626
211	50	booking	122	consumed	-1.00	22.00	21.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 06:03:00.027191	2026-03-29 06:03:00.027191
212	50	booking	123	consumed	-1.00	21.00	20.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 06:21:25.625866	2026-03-29 06:21:25.625866
213	50	booking	124	consumed	-1.00	20.00	19.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 06:33:34.032778	2026-03-29 06:33:34.032778
214	50	booking	125	consumed	-1.00	19.00	18.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 06:53:33.94747	2026-03-29 06:53:33.94747
215	50	booking	126	consumed	-1.00	16.00	15.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 07:04:16.484249	2026-03-29 07:04:16.484249
216	50	booking	127	consumed	-1.00	16.00	15.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 07:04:18.194344	2026-03-29 07:04:18.194344
217	50	booking	128	consumed	-1.00	14.00	13.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 07:13:06.826608	2026-03-29 07:13:06.826608
218	50	booking	129	consumed	-1.00	12.00	11.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 10:03:42.301188	2026-03-29 10:03:42.301188
219	50	booking	130	consumed	-1.00	10.00	9.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 10:06:25.309136	2026-03-29 10:06:25.309136
220	38	booking	131	consumed	-1.00	2.00	1.00	Stock consumed for booking item: HONEY RAW [300GM] (Qty: 1.0)	2026-03-29 10:06:56.680449	2026-03-29 10:06:56.680449
221	38	booking	132	consumed	-1.00	1.00	0.00	Stock consumed for booking item: HONEY RAW [300GM] (Qty: 1.0)	2026-03-29 10:07:20.200086	2026-03-29 10:07:20.200086
222	40	booking	133	consumed	-1.00	5.00	4.00	Stock consumed for booking item: GROUNDNUT OIL [1LTR] (Qty: 1.0)	2026-03-29 10:08:36.922187	2026-03-29 10:08:36.922187
223	40	booking	134	consumed	-1.00	4.00	3.00	Stock consumed for booking item: GROUNDNUT OIL [1LTR] (Qty: 1.0)	2026-03-29 10:09:02.682615	2026-03-29 10:09:02.682615
224	50	booking	135	consumed	-1.00	9.00	8.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 10:17:26.711216	2026-03-29 10:17:26.711216
225	40	booking	135	consumed	-1.00	3.00	2.00	Stock consumed for booking item: GROUNDNUT OIL [1LTR] (Qty: 1.0)	2026-03-29 10:17:33.344083	2026-03-29 10:17:33.344083
226	45	booking	136	consumed	-1.00	5.00	4.00	Stock consumed for booking item: SAFFLOWER OIL [1LTR] (Qty: 1.0)	2026-03-29 10:18:13.064855	2026-03-29 10:18:13.064855
227	50	booking	137	consumed	-1.00	8.00	7.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 10:19:12.938566	2026-03-29 10:19:12.938566
228	50	booking	138	consumed	-1.00	7.00	6.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 10:23:55.352866	2026-03-29 10:23:55.352866
229	50	booking	139	consumed	-1.00	6.00	5.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 10:28:01.120543	2026-03-29 10:28:01.120543
230	50	booking	140	consumed	-1.00	5.00	4.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 10:31:14.234431	2026-03-29 10:31:14.234431
231	50	booking	141	consumed	-1.00	4.00	3.00	Stock consumed for booking item: Test product (Qty: 1.0)	2026-03-29 10:41:19.163048	2026-03-29 10:41:19.163048
\.


--
-- Data for Name: stores; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.stores (id, name, description, address, city, state, pincode, contact_person, contact_mobile, email, status, gst_no, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sub_agents; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.sub_agents (id, first_name, last_name, middle_name, email, mobile, password_digest, plain_password, original_password, role_id, gender, birth_date, pan_no, aadhar_no, gst_no, company_name, address, city, state, pincode, country, profile_picture, bank_name, account_no, ifsc_code, account_holder_name, account_type, upi_id, emergency_contact_name, emergency_contact_mobile, joining_date, salary, notes, status, distributor_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: subscription_templates; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.subscription_templates (id, customer_id, product_id, delivery_person_id, quantity, unit, price, delivery_time, is_active, template_name, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: system_settings; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.system_settings (id, key, value, setting_type, description, default_main_agent_commission, default_affiliate_commission, default_ambassador_commission, default_company_expenses, created_at, updated_at, business_name, address, mobile, email, gstin, pan_number, account_holder_name, bank_name, account_number, ifsc_code, upi_id, qr_code_path, terms_and_conditions, collect_from_store_enabled, delivery_only_at_shop, shop_addresses) FROM stdin;
3	business_config	business configuration	configuration	Business configuration settings	\N	\N	\N	\N	2026-03-25 04:49:06.327843	2026-03-25 04:49:07.616501	Marali Santhe	dfd	09190939393	9093939393fdfds@gmail.com			Ecommerce Store Pvt Ltd	CNRB0003194	3194201000718	SBIN0001234		\N		\N	\N	\N
4	system_config	system configuration	configuration	System configuration settings	\N	\N	\N	\N	2026-03-25 04:49:08.920571	2026-03-25 04:49:10.398214	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	t	["abc,bcd"]
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.user_roles (id, name, description, active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.users (id, first_name, last_name, email, mobile, created_at, updated_at, middle_name, encrypted_password, user_type, role, role_id, status, is_active, is_verified, birth_date, gender, pan_no, aadhar_no, gst_no, company_name, address, city, state, pincode, country, profile_picture, bank_name, account_no, ifsc_code, account_holder_name, account_type, upi_id, emergency_contact_name, emergency_contact_mobile, department, designation, joining_date, salary, employee_id, reporting_manager_id, permissions, sidebar_permissions, last_login_at, login_count, email_verified_at, mobile_verified_at, two_factor_enabled, reset_password_token, reset_password_sent_at, remember_created_at, sign_in_count, current_sign_in_at, last_sign_in_at, current_sign_in_ip, last_sign_in_ip, confirmation_token, confirmed_at, confirmation_sent_at, unlock_token, locked_at, failed_attempts, notes, created_by, updated_by, deleted_at, original_password, authenticatable_type, authenticatable_id) FROM stdin;
11	rajesh	ar	raj@gmail.com	9879879879	2026-02-22 02:23:10.503634	2026-02-22 02:23:10.503634		$2a$12$sEdCu6/LX.q3q1DfgKVqUOXOYay1MnQj5.IME1NNERLAi1cdEO3.u	customer	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	123 Main Street, Apartment 4B	Mumbai	Maharashtra	400001	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
13	pramod	bhat	pramsddodbha8@gmail.com	9190939300	2026-02-22 06:28:33.603929	2026-02-22 06:28:33.603929	\N	$2a$12$b52KqulR5.Y1W065fax.le3bVlZShS6vXq0Sgso/J01skDp8w8bOC	customer	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N		Unknown	Unknown	000000	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
2	Test	User	test1771316179@example.com	#{Time.current.to_i}	2026-02-17 08:16:27.928046	2026-02-17 08:16:27.928046	\N	$2a$12$lcuFV/t5i17Ijx20z7YD2.vIEewChdDTJw9g8DqWp7EOy7pFjaFmi	customer	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
4	Test Franchise Store	Franchise	franchise1@example.com	9876543210	2026-02-18 11:15:49.981965	2026-02-18 11:15:49.981965	\N	$2a$12$gCpRxuZtV8mXWz36cqp9G.4h.f818IwM40xv0wTHfLlMNR5fH7ig6	franchise	super_admin	1	t	t	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
3	Test	Flash	testflash@example.com	8888888888	2026-02-17 09:20:32.118752	2026-02-19 07:01:33.8557	\N	$2a$12$W8MTCiUpdLYRKFNNINnDJOWUWkTHKYevDzpNcP3/oTzRfZ/BvhJZG	admin	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	["delivery_people"]	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
5	Test	Customer	assasa@gmail.com	9393939393	2026-02-20 13:38:06.84574	2026-02-20 13:38:06.84574	Mobile	$2a$12$3SW.vAWgdHxGNvigekyuVOhY/VH2JNYVrgr./kf1Ru3kzit8oM1hu	customer	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	123 Test Street, Test Area	Mumbai	Maharashtra	400001	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
6	Test	Customer	asseasa@gmail.com	9393939313	2026-02-21 02:39:16.334135	2026-02-21 02:39:16.334135	Mobile	$2a$12$dHpp7OPaWd/NCVCFZXzaO.Ldte9h//GsT4t06aOJC81smlQU/BJ1O	customer	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	123 Test Street, Test Area	Mumbai	Maharashtra	400001	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
7	TestFixed	Customer	testfixed@example.com	9876543212	2026-02-21 02:43:48.821806	2026-02-21 02:43:48.821806	Web	$2a$12$wmi5NYGLdTJZMuhsAl9OKOX5pl4JfdLW33DtTVhScbfmQu9KizfWG	customer	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	Test Address	Unknown	Unknown	000000	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
9	Manjunath	Bhat	sagar_mopagar@gmail.com	9900503118	2026-02-21 09:49:29.65782	2026-02-21 09:49:29.65782	\N	$2a$12$NC31BVw0f9R.2Sq9XDKTme6ElW01vO/a4iKXTgLREgVMGWma3QeZq	customer	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N		Unknown	Unknown	000000	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
78	Ram	Bhat	prdddamodbha8@gmail.com	8292929292	2026-03-08 09:47:35.523284	2026-03-08 09:47:35.523284	\N	$2a$12$ike9pBLPOr37zcFN5xiFe.arSMGe1NevgbMsNIHdmERxDtnS8WY.C	customer	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	dfd	Unknown	Unknown	000000	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
79	Javeed	Patel	raghubit040@gmail.com	919663838730	2026-03-08 11:32:15.894369	2026-03-08 11:32:15.894369	\N	$2a$12$YMubTE/vIda84KGhn7lIyObErAFpge9aehhUea3BUHlu.lPceuaaa	delivery_person	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	NR colony 	Bangalore	Karnataka	560004	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
80	Javeed	Patel	maralisanthe@gmail.com	917975918232	2026-03-20 07:59:01.955945	2026-03-20 07:59:01.955945	\N	$2a$12$prc0D8/AfMOuhJDAEwS9NOTmPxT3hX9hTlRryFmbSTf6yijE56vga	delivery_person	super_admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	NR colony Bangalore	Bangalore	Karnataka	560004	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
1	Admin	User	admin@maralisanthe.com	9999999999	2026-02-12 11:39:37.772197	2026-03-07 13:35:08.66239	\N	$2a$12$F3y6NUiRv9pvLpslJGXiFuiPkhB5QPVd5j4vpVdPmadgq8rHF0I52	admin	admin	\N	t	t	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	India	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	{"dashboard":{"view":true,"create":true,"edit":true,"delete":true},"bookings":{"view":true,"create":true,"edit":true,"delete":true},"stores":{"view":true,"create":true,"edit":true,"delete":true},"customer_formats":{"view":true,"create":true,"edit":true,"delete":true},"subscriptions":{"view":true,"create":true,"edit":true,"delete":true},"invoices":{"view":true,"create":true,"edit":true,"delete":true},"notes":{"view":true,"create":true,"edit":true,"delete":true},"pending_amounts":{"view":true,"create":true,"edit":true,"delete":true},"invoice_check":{"view":true,"create":true,"edit":true,"delete":true},"vendors":{"view":true,"create":true,"edit":true,"delete":true},"vendor_purchases":{"view":true,"create":true,"edit":true,"delete":true},"customers":{"view":true,"create":true,"edit":true,"delete":true},"categories":{"view":true,"create":true,"edit":true,"delete":true},"products":{"view":true,"create":true,"edit":true,"delete":true},"coupons":{"view":true,"create":true,"edit":true,"delete":true},"customer_wallets":{"view":true,"create":true,"edit":true,"delete":true},"franchises":{"view":true,"create":true,"edit":true,"delete":true},"affiliates":{"view":true,"create":true,"edit":true,"delete":true},"subscription_templates":{"view":true,"create":true,"edit":true,"delete":true},"delivery_people":{"view":true,"create":true,"edit":true,"delete":true},"imports":{"view":true,"create":true,"edit":true,"delete":true},"reports":{"view":true,"create":true,"edit":true,"delete":true},"system_settings":{"view":true,"create":true,"edit":true,"delete":true},"user_roles":{"view":true,"create":true,"edit":true,"delete":true},"banners":{"view":true,"create":true,"edit":true,"delete":true},"client_requests":{"view":true,"create":true,"edit":true,"delete":true},"helpdesk":{"view":true,"create":true,"edit":true,"delete":true},"users":{"view":true,"create":true,"edit":true,"delete":true},"leads":{"view":true,"create":true,"edit":true,"delete":true},"life_insurance":{"view":true,"create":true,"edit":true,"delete":true},"health_insurance":{"view":true,"create":true,"edit":true,"delete":true},"motor_insurance":{"view":true,"create":true,"edit":true,"delete":true},"other_insurance":{"view":true,"create":true,"edit":true,"delete":true},"roles":{"view":true,"create":true,"edit":true,"delete":true},"settings":{"view":true,"create":true,"edit":true,"delete":true},"referrals":{"view":true,"create":true,"edit":true,"delete":true}}	\N	0	\N	\N	f	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: vendor_invoices; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.vendor_invoices (id, vendor_purchase_id, invoice_number, total_amount, status, invoice_date, share_token, notes, created_at, updated_at) FROM stdin;
3	11	VI20260326-0001	46.0	1	2026-03-26	AEfT0PcWVJaJtc7PmF6WAzEzLHlsUca3o4Vb7ehBfo0	Invoice generated for vendor purchase #VP000011	2026-03-26 06:47:28.932104	2026-03-26 06:47:28.932104
4	12	VI20260326-0002	12.0	1	2026-03-26	V2XhkXqkVCocLtkav8p5EziUXWHqtA1ak_6tvHcQV-8	Invoice generated for vendor purchase #VP000012	2026-03-26 07:20:44.720248	2026-03-26 07:20:44.720248
\.


--
-- Data for Name: vendor_payments; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.vendor_payments (id, vendor_id, vendor_purchase_id, amount_paid, payment_date, payment_mode, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: vendor_purchase_items; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.vendor_purchase_items (id, vendor_purchase_id, product_id, quantity, purchase_price, selling_price, line_total, created_at, updated_at) FROM stdin;
11	11	37	2.0	23.0	455.0	46.0	2026-03-26 06:45:46.787441	2026-03-26 06:45:46.787441
12	12	42	3.0	4.0	344.0	12.0	2026-03-26 07:19:47.428106	2026-03-26 07:19:47.428106
\.


--
-- Data for Name: vendor_purchases; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.vendor_purchases (id, vendor_id, purchase_date, total_amount, paid_amount, status, notes, created_at, updated_at) FROM stdin;
11	11	2026-03-26	46.0	46.0	completed	sd	2026-03-26 06:45:46.532347	2026-03-26 06:47:52.737148
12	11	2026-03-26	12.0	0.0	completed	sd	2026-03-26 07:19:45.714883	2026-03-26 07:20:11.425749
\.


--
-- Data for Name: vendors; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.vendors (id, name, phone, email, address, payment_type, opening_balance, status, created_at, updated_at) FROM stdin;
11	System Default	0000000000	system@default.com	System Generated	Cash	\N	t	2026-03-19 08:25:49.567116	2026-03-19 08:25:49.567116
\.


--
-- Data for Name: wallet_transactions; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.wallet_transactions (id, customer_wallet_id, transaction_type, amount, balance_after, description, reference_number, metadata, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: wishlists; Type: TABLE DATA; Schema: public; Owner: marali_sante_user
--

COPY public.wishlists (id, customer_id, product_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.active_storage_attachments_id_seq', 26, true);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.active_storage_blobs_id_seq', 26, true);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.active_storage_variant_records_id_seq', 1, false);


--
-- Name: affiliates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.affiliates_id_seq', 7, true);


--
-- Name: banners_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.banners_id_seq', 4, true);


--
-- Name: booking_invoices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.booking_invoices_id_seq', 33, true);


--
-- Name: booking_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.booking_items_id_seq', 169, true);


--
-- Name: booking_schedules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.booking_schedules_id_seq', 1, false);


--
-- Name: bookings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.bookings_id_seq', 141, true);


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.categories_id_seq', 15, true);


--
-- Name: client_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.client_requests_id_seq', 6, true);


--
-- Name: coupons_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.coupons_id_seq', 1, false);


--
-- Name: customer_addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.customer_addresses_id_seq', 2, true);


--
-- Name: customer_formats_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.customer_formats_id_seq', 320, true);


--
-- Name: customer_wallets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.customer_wallets_id_seq', 1, false);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.customers_id_seq', 489, true);


--
-- Name: delivery_people_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.delivery_people_id_seq', 17, true);


--
-- Name: delivery_rules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.delivery_rules_id_seq', 47, true);


--
-- Name: device_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.device_tokens_id_seq', 1, false);


--
-- Name: franchises_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.franchises_id_seq', 7, true);


--
-- Name: invoice_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.invoice_items_id_seq', 408, true);


--
-- Name: invoices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.invoices_id_seq', 317, true);


--
-- Name: leads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.leads_id_seq', 1, false);


--
-- Name: milk_delivery_tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.milk_delivery_tasks_id_seq', 9463, true);


--
-- Name: milk_subscriptions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.milk_subscriptions_id_seq', 335, true);


--
-- Name: notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.notes_id_seq', 28, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.notifications_id_seq', 1, false);


--
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.order_items_id_seq', 1, false);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.orders_id_seq', 1, false);


--
-- Name: pending_amounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.pending_amounts_id_seq', 32, true);


--
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.permissions_id_seq', 1, false);


--
-- Name: product_ratings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.product_ratings_id_seq', 1, false);


--
-- Name: product_reviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.product_reviews_id_seq', 1, false);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.products_id_seq', 50, true);


--
-- Name: referrals_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.referrals_id_seq', 7, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.roles_id_seq', 7, true);


--
-- Name: sale_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.sale_items_id_seq', 29, true);


--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_cache_entries_id_seq', 1, false);


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_blocked_executions_id_seq', 1, false);


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_claimed_executions_id_seq', 1, false);


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_failed_executions_id_seq', 1, false);


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_jobs_id_seq', 37, true);


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_pauses_id_seq', 1, false);


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_processes_id_seq', 1, false);


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_ready_executions_id_seq', 37, true);


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_recurring_executions_id_seq', 1, false);


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_recurring_tasks_id_seq', 1, false);


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_scheduled_executions_id_seq', 1, false);


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.solid_queue_semaphores_id_seq', 1, false);


--
-- Name: stock_batches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.stock_batches_id_seq', 62, true);


--
-- Name: stock_movements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.stock_movements_id_seq', 231, true);


--
-- Name: stores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.stores_id_seq', 2, true);


--
-- Name: sub_agents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.sub_agents_id_seq', 1, false);


--
-- Name: subscription_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.subscription_templates_id_seq', 1, false);


--
-- Name: system_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.system_settings_id_seq', 4, true);


--
-- Name: user_roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.user_roles_id_seq', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.users_id_seq', 80, true);


--
-- Name: vendor_invoices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.vendor_invoices_id_seq', 4, true);


--
-- Name: vendor_payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.vendor_payments_id_seq', 1, false);


--
-- Name: vendor_purchase_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.vendor_purchase_items_id_seq', 12, true);


--
-- Name: vendor_purchases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.vendor_purchases_id_seq', 12, true);


--
-- Name: vendors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.vendors_id_seq', 11, true);


--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.wallet_transactions_id_seq', 1, false);


--
-- Name: wishlists_id_seq; Type: SEQUENCE SET; Schema: public; Owner: marali_sante_user
--

SELECT pg_catalog.setval('public.wishlists_id_seq', 1, false);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: affiliates affiliates_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.affiliates
    ADD CONSTRAINT affiliates_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: banners banners_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.banners
    ADD CONSTRAINT banners_pkey PRIMARY KEY (id);


--
-- Name: booking_invoices booking_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_invoices
    ADD CONSTRAINT booking_invoices_pkey PRIMARY KEY (id);


--
-- Name: booking_items booking_items_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT booking_items_pkey PRIMARY KEY (id);


--
-- Name: booking_schedules booking_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_schedules
    ADD CONSTRAINT booking_schedules_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: client_requests client_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.client_requests
    ADD CONSTRAINT client_requests_pkey PRIMARY KEY (id);


--
-- Name: coupons coupons_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT coupons_pkey PRIMARY KEY (id);


--
-- Name: customer_addresses customer_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_addresses
    ADD CONSTRAINT customer_addresses_pkey PRIMARY KEY (id);


--
-- Name: customer_formats customer_formats_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_formats
    ADD CONSTRAINT customer_formats_pkey PRIMARY KEY (id);


--
-- Name: customer_wallets customer_wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_wallets
    ADD CONSTRAINT customer_wallets_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: delivery_people delivery_people_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.delivery_people
    ADD CONSTRAINT delivery_people_pkey PRIMARY KEY (id);


--
-- Name: delivery_rules delivery_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.delivery_rules
    ADD CONSTRAINT delivery_rules_pkey PRIMARY KEY (id);


--
-- Name: device_tokens device_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_pkey PRIMARY KEY (id);


--
-- Name: franchises franchises_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.franchises
    ADD CONSTRAINT franchises_pkey PRIMARY KEY (id);


--
-- Name: invoice_items invoice_items_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: leads leads_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_pkey PRIMARY KEY (id);


--
-- Name: milk_delivery_tasks milk_delivery_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_delivery_tasks
    ADD CONSTRAINT milk_delivery_tasks_pkey PRIMARY KEY (id);


--
-- Name: milk_subscriptions milk_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_subscriptions
    ADD CONSTRAINT milk_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: pending_amounts pending_amounts_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.pending_amounts
    ADD CONSTRAINT pending_amounts_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: product_ratings product_ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_ratings
    ADD CONSTRAINT product_ratings_pkey PRIMARY KEY (id);


--
-- Name: product_reviews product_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_reviews
    ADD CONSTRAINT product_reviews_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: referrals referrals_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: sale_items sale_items_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT sale_items_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: solid_cache_entries solid_cache_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_cache_entries
    ADD CONSTRAINT solid_cache_entries_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_blocked_executions solid_queue_blocked_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT solid_queue_blocked_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_claimed_executions solid_queue_claimed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT solid_queue_claimed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_failed_executions solid_queue_failed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT solid_queue_failed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_jobs solid_queue_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_jobs
    ADD CONSTRAINT solid_queue_jobs_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_pauses solid_queue_pauses_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_pauses
    ADD CONSTRAINT solid_queue_pauses_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_processes solid_queue_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_processes
    ADD CONSTRAINT solid_queue_processes_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_ready_executions solid_queue_ready_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT solid_queue_ready_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_executions solid_queue_recurring_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT solid_queue_recurring_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_tasks solid_queue_recurring_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks
    ADD CONSTRAINT solid_queue_recurring_tasks_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_scheduled_executions solid_queue_scheduled_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT solid_queue_scheduled_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_semaphores solid_queue_semaphores_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_semaphores
    ADD CONSTRAINT solid_queue_semaphores_pkey PRIMARY KEY (id);


--
-- Name: stock_batches stock_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stock_batches
    ADD CONSTRAINT stock_batches_pkey PRIMARY KEY (id);


--
-- Name: stock_movements stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: sub_agents sub_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.sub_agents
    ADD CONSTRAINT sub_agents_pkey PRIMARY KEY (id);


--
-- Name: subscription_templates subscription_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.subscription_templates
    ADD CONSTRAINT subscription_templates_pkey PRIMARY KEY (id);


--
-- Name: system_settings system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vendor_invoices vendor_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_invoices
    ADD CONSTRAINT vendor_invoices_pkey PRIMARY KEY (id);


--
-- Name: vendor_payments vendor_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_payments
    ADD CONSTRAINT vendor_payments_pkey PRIMARY KEY (id);


--
-- Name: vendor_purchase_items vendor_purchase_items_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_purchase_items
    ADD CONSTRAINT vendor_purchase_items_pkey PRIMARY KEY (id);


--
-- Name: vendor_purchases vendor_purchases_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_purchases
    ADD CONSTRAINT vendor_purchases_pkey PRIMARY KEY (id);


--
-- Name: vendors vendors_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_pkey PRIMARY KEY (id);


--
-- Name: wallet_transactions wallet_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_pkey PRIMARY KEY (id);


--
-- Name: wishlists wishlists_pkey; Type: CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.wishlists
    ADD CONSTRAINT wishlists_pkey PRIMARY KEY (id);


--
-- Name: idx_milk_subscriptions_dates; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX idx_milk_subscriptions_dates ON public.milk_subscriptions USING btree (start_date, end_date);


--
-- Name: idx_milk_subscriptions_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX idx_milk_subscriptions_status ON public.milk_subscriptions USING btree (status);


--
-- Name: idx_on_delivery_person_id_delivery_date_8b580f1b82; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX idx_on_delivery_person_id_delivery_date_8b580f1b82 ON public.milk_delivery_tasks USING btree (delivery_person_id, delivery_date);


--
-- Name: idx_stock_movements_created_at; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX idx_stock_movements_created_at ON public.stock_movements USING btree (created_at);


--
-- Name: idx_stock_movements_movement_type; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX idx_stock_movements_movement_type ON public.stock_movements USING btree (movement_type);


--
-- Name: idx_stock_movements_product_created; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX idx_stock_movements_product_created ON public.stock_movements USING btree (product_id, created_at);


--
-- Name: idx_stock_movements_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX idx_stock_movements_product_id ON public.stock_movements USING btree (product_id);


--
-- Name: idx_stock_movements_ref_type_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX idx_stock_movements_ref_type_id ON public.stock_movements USING btree (reference_type, reference_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_affiliates_on_email; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_affiliates_on_email ON public.affiliates USING btree (email);


--
-- Name: index_affiliates_on_mobile; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_affiliates_on_mobile ON public.affiliates USING btree (mobile);


--
-- Name: index_banners_on_display_location; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_banners_on_display_location ON public.banners USING btree (display_location);


--
-- Name: index_banners_on_display_order; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_banners_on_display_order ON public.banners USING btree (display_order);


--
-- Name: index_banners_on_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_banners_on_status ON public.banners USING btree (status);


--
-- Name: index_booking_invoices_on_booking_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_booking_invoices_on_booking_id ON public.booking_invoices USING btree (booking_id);


--
-- Name: index_booking_invoices_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_booking_invoices_on_customer_id ON public.booking_invoices USING btree (customer_id);


--
-- Name: index_booking_invoices_on_invoice_number; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_booking_invoices_on_invoice_number ON public.booking_invoices USING btree (invoice_number);


--
-- Name: index_booking_invoices_on_share_token; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_booking_invoices_on_share_token ON public.booking_invoices USING btree (share_token);


--
-- Name: index_booking_schedules_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_booking_schedules_on_customer_id ON public.booking_schedules USING btree (customer_id);


--
-- Name: index_booking_schedules_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_booking_schedules_on_product_id ON public.booking_schedules USING btree (product_id);


--
-- Name: index_bookings_on_booked_by; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_booked_by ON public.bookings USING btree (booked_by);


--
-- Name: index_bookings_on_booking_schedule_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_booking_schedule_id ON public.bookings USING btree (booking_schedule_id);


--
-- Name: index_bookings_on_cashfree_order_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_cashfree_order_id ON public.bookings USING btree (cashfree_order_id);


--
-- Name: index_bookings_on_cashfree_payment_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_cashfree_payment_id ON public.bookings USING btree (cashfree_payment_id);


--
-- Name: index_bookings_on_courier_service; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_courier_service ON public.bookings USING btree (courier_service);


--
-- Name: index_bookings_on_delivery_person_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_delivery_person_id ON public.bookings USING btree (delivery_person_id);


--
-- Name: index_bookings_on_delivery_time; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_delivery_time ON public.bookings USING btree (delivery_time);


--
-- Name: index_bookings_on_expected_delivery_date; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_expected_delivery_date ON public.bookings USING btree (expected_delivery_date);


--
-- Name: index_bookings_on_franchise_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_franchise_id ON public.bookings USING btree (franchise_id);


--
-- Name: index_bookings_on_payment_gateway; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_payment_gateway ON public.bookings USING btree (payment_gateway);


--
-- Name: index_bookings_on_stage_updated_at; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_stage_updated_at ON public.bookings USING btree (stage_updated_at);


--
-- Name: index_bookings_on_stage_updated_by; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_stage_updated_by ON public.bookings USING btree (stage_updated_by);


--
-- Name: index_bookings_on_store_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_store_id ON public.bookings USING btree (store_id);


--
-- Name: index_bookings_on_tracking_number; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_bookings_on_tracking_number ON public.bookings USING btree (tracking_number);


--
-- Name: index_categories_on_display_order; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_categories_on_display_order ON public.categories USING btree (display_order);


--
-- Name: index_categories_on_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_categories_on_status ON public.categories USING btree (status);


--
-- Name: index_client_requests_on_assignee_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_client_requests_on_assignee_id ON public.client_requests USING btree (assignee_id);


--
-- Name: index_client_requests_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_client_requests_on_customer_id ON public.client_requests USING btree (customer_id);


--
-- Name: index_client_requests_on_department; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_client_requests_on_department ON public.client_requests USING btree (department);


--
-- Name: index_client_requests_on_estimated_resolution_time; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_client_requests_on_estimated_resolution_time ON public.client_requests USING btree (estimated_resolution_time);


--
-- Name: index_client_requests_on_stage; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_client_requests_on_stage ON public.client_requests USING btree (stage);


--
-- Name: index_client_requests_on_ticket_number; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_client_requests_on_ticket_number ON public.client_requests USING btree (ticket_number);


--
-- Name: index_coupons_on_code; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_coupons_on_code ON public.coupons USING btree (code);


--
-- Name: index_customer_addresses_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_customer_addresses_on_customer_id ON public.customer_addresses USING btree (customer_id);


--
-- Name: index_customer_formats_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_customer_formats_on_customer_id ON public.customer_formats USING btree (customer_id);


--
-- Name: index_customer_formats_on_delivery_person_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_customer_formats_on_delivery_person_id ON public.customer_formats USING btree (delivery_person_id);


--
-- Name: index_customer_formats_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_customer_formats_on_product_id ON public.customer_formats USING btree (product_id);


--
-- Name: index_customer_wallets_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_customer_wallets_on_customer_id ON public.customer_wallets USING btree (customer_id);


--
-- Name: index_customers_on_location; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_customers_on_location ON public.customers USING btree (latitude, longitude);


--
-- Name: index_customers_on_whatsapp_number; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_customers_on_whatsapp_number ON public.customers USING btree (whatsapp_number);


--
-- Name: index_delivery_rules_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_delivery_rules_on_product_id ON public.delivery_rules USING btree (product_id);


--
-- Name: index_delivery_rules_on_rule_type; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_delivery_rules_on_rule_type ON public.delivery_rules USING btree (rule_type);


--
-- Name: index_device_tokens_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_device_tokens_on_customer_id ON public.device_tokens USING btree (customer_id);


--
-- Name: index_device_tokens_on_delivery_person_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_device_tokens_on_delivery_person_id ON public.device_tokens USING btree (delivery_person_id);


--
-- Name: index_franchises_on_email; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_franchises_on_email ON public.franchises USING btree (email);


--
-- Name: index_franchises_on_mobile; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_franchises_on_mobile ON public.franchises USING btree (mobile);


--
-- Name: index_franchises_on_pan_no; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_franchises_on_pan_no ON public.franchises USING btree (pan_no);


--
-- Name: index_franchises_on_user_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_franchises_on_user_id ON public.franchises USING btree (user_id);


--
-- Name: index_invoice_items_on_invoice_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_invoice_items_on_invoice_id ON public.invoice_items USING btree (invoice_id);


--
-- Name: index_invoice_items_on_milk_delivery_task_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_invoice_items_on_milk_delivery_task_id ON public.invoice_items USING btree (milk_delivery_task_id);


--
-- Name: index_invoice_items_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_invoice_items_on_product_id ON public.invoice_items USING btree (product_id);


--
-- Name: index_invoices_on_invoice_number; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_invoices_on_invoice_number ON public.invoices USING btree (invoice_number);


--
-- Name: index_invoices_on_share_token; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_invoices_on_share_token ON public.invoices USING btree (share_token);


--
-- Name: index_milk_delivery_tasks_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_delivery_tasks_on_customer_id ON public.milk_delivery_tasks USING btree (customer_id);


--
-- Name: index_milk_delivery_tasks_on_customer_id_and_delivery_date; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_delivery_tasks_on_customer_id_and_delivery_date ON public.milk_delivery_tasks USING btree (customer_id, delivery_date);


--
-- Name: index_milk_delivery_tasks_on_delivery_date; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_delivery_tasks_on_delivery_date ON public.milk_delivery_tasks USING btree (delivery_date);


--
-- Name: index_milk_delivery_tasks_on_delivery_person_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_delivery_tasks_on_delivery_person_id ON public.milk_delivery_tasks USING btree (delivery_person_id);


--
-- Name: index_milk_delivery_tasks_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_delivery_tasks_on_product_id ON public.milk_delivery_tasks USING btree (product_id);


--
-- Name: index_milk_delivery_tasks_on_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_delivery_tasks_on_status ON public.milk_delivery_tasks USING btree (status);


--
-- Name: index_milk_delivery_tasks_on_subscription_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_delivery_tasks_on_subscription_id ON public.milk_delivery_tasks USING btree (subscription_id);


--
-- Name: index_milk_subscriptions_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_subscriptions_on_customer_id ON public.milk_subscriptions USING btree (customer_id);


--
-- Name: index_milk_subscriptions_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_milk_subscriptions_on_product_id ON public.milk_subscriptions USING btree (product_id);


--
-- Name: index_notes_on_created_by_user_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_notes_on_created_by_user_id ON public.notes USING btree (created_by_user_id);


--
-- Name: index_notes_on_note_date; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_notes_on_note_date ON public.notes USING btree (note_date);


--
-- Name: index_notes_on_payment_method; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_notes_on_payment_method ON public.notes USING btree (payment_method);


--
-- Name: index_notes_on_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_notes_on_status ON public.notes USING btree (status);


--
-- Name: index_notifications_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_notifications_on_customer_id ON public.notifications USING btree (customer_id);


--
-- Name: index_orders_on_booking_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_orders_on_booking_id ON public.orders USING btree (booking_id);


--
-- Name: index_pending_amounts_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_pending_amounts_on_customer_id ON public.pending_amounts USING btree (customer_id);


--
-- Name: index_permissions_on_name; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_permissions_on_name ON public.permissions USING btree (name);


--
-- Name: index_permissions_on_resource_and_action; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_permissions_on_resource_and_action ON public.permissions USING btree (resource, action);


--
-- Name: index_product_ratings_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_ratings_on_customer_id ON public.product_ratings USING btree (customer_id);


--
-- Name: index_product_ratings_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_ratings_on_product_id ON public.product_ratings USING btree (product_id);


--
-- Name: index_product_ratings_on_product_id_and_rating; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_ratings_on_product_id_and_rating ON public.product_ratings USING btree (product_id, rating);


--
-- Name: index_product_ratings_on_product_id_and_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_ratings_on_product_id_and_status ON public.product_ratings USING btree (product_id, status);


--
-- Name: index_product_ratings_on_user_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_ratings_on_user_id ON public.product_ratings USING btree (user_id);


--
-- Name: index_product_reviews_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_reviews_on_customer_id ON public.product_reviews USING btree (customer_id);


--
-- Name: index_product_reviews_on_customer_id_and_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_product_reviews_on_customer_id_and_product_id ON public.product_reviews USING btree (customer_id, product_id) WHERE (customer_id IS NOT NULL);


--
-- Name: index_product_reviews_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_reviews_on_product_id ON public.product_reviews USING btree (product_id);


--
-- Name: index_product_reviews_on_product_id_and_created_at; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_reviews_on_product_id_and_created_at ON public.product_reviews USING btree (product_id, created_at);


--
-- Name: index_product_reviews_on_product_id_and_rating; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_reviews_on_product_id_and_rating ON public.product_reviews USING btree (product_id, rating);


--
-- Name: index_product_reviews_on_product_id_and_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_reviews_on_product_id_and_status ON public.product_reviews USING btree (product_id, status);


--
-- Name: index_product_reviews_on_user_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_product_reviews_on_user_id ON public.product_reviews USING btree (user_id);


--
-- Name: index_products_on_category_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_products_on_category_id ON public.products USING btree (category_id);


--
-- Name: index_products_on_is_occasional_product; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_products_on_is_occasional_product ON public.products USING btree (is_occasional_product);


--
-- Name: index_products_on_is_subscription_enabled; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_products_on_is_subscription_enabled ON public.products USING btree (is_subscription_enabled);


--
-- Name: index_products_on_last_price_update; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_products_on_last_price_update ON public.products USING btree (last_price_update);


--
-- Name: index_products_on_name; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_products_on_name ON public.products USING btree (name);


--
-- Name: index_products_on_occasional_dates; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_products_on_occasional_dates ON public.products USING btree (is_occasional_product, occasional_start_date, occasional_end_date);


--
-- Name: index_products_on_product_type; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_products_on_product_type ON public.products USING btree (product_type);


--
-- Name: index_products_on_sku; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_products_on_sku ON public.products USING btree (sku);


--
-- Name: index_products_on_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_products_on_status ON public.products USING btree (status);


--
-- Name: index_referrals_on_affiliate_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_referrals_on_affiliate_id ON public.referrals USING btree (affiliate_id);


--
-- Name: index_referrals_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_referrals_on_customer_id ON public.referrals USING btree (customer_id);


--
-- Name: index_referrals_on_referral_source; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_referrals_on_referral_source ON public.referrals USING btree (referral_source);


--
-- Name: index_referrals_on_referring_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_referrals_on_referring_customer_id ON public.referrals USING btree (referring_customer_id);


--
-- Name: index_roles_on_name; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_roles_on_name ON public.roles USING btree (name);


--
-- Name: index_sale_items_on_booking_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_sale_items_on_booking_id ON public.sale_items USING btree (booking_id);


--
-- Name: index_sale_items_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_sale_items_on_product_id ON public.sale_items USING btree (product_id);


--
-- Name: index_sale_items_on_stock_batch_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_sale_items_on_stock_batch_id ON public.sale_items USING btree (stock_batch_id);


--
-- Name: index_solid_cache_entries_on_byte_size; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_cache_entries_on_byte_size ON public.solid_cache_entries USING btree (byte_size);


--
-- Name: index_solid_cache_entries_on_key_hash; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_cache_entries_on_key_hash ON public.solid_cache_entries USING btree (key_hash);


--
-- Name: index_solid_cache_entries_on_key_hash_and_byte_size; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_cache_entries_on_key_hash_and_byte_size ON public.solid_cache_entries USING btree (key_hash, byte_size);


--
-- Name: index_solid_queue_blocked_executions_for_maintenance; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_blocked_executions_for_maintenance ON public.solid_queue_blocked_executions USING btree (expires_at, concurrency_key);


--
-- Name: index_solid_queue_blocked_executions_for_release; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_blocked_executions_for_release ON public.solid_queue_blocked_executions USING btree (concurrency_key, priority, job_id);


--
-- Name: index_solid_queue_blocked_executions_on_job_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_blocked_executions_on_job_id ON public.solid_queue_blocked_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_job_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_claimed_executions_on_job_id ON public.solid_queue_claimed_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_process_id_and_job_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_claimed_executions_on_process_id_and_job_id ON public.solid_queue_claimed_executions USING btree (process_id, job_id);


--
-- Name: index_solid_queue_dispatch_all; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_dispatch_all ON public.solid_queue_scheduled_executions USING btree (scheduled_at, priority, job_id);


--
-- Name: index_solid_queue_failed_executions_on_job_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_failed_executions_on_job_id ON public.solid_queue_failed_executions USING btree (job_id);


--
-- Name: index_solid_queue_jobs_for_alerting; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_jobs_for_alerting ON public.solid_queue_jobs USING btree (scheduled_at, finished_at);


--
-- Name: index_solid_queue_jobs_for_filtering; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_jobs_for_filtering ON public.solid_queue_jobs USING btree (queue_name, finished_at);


--
-- Name: index_solid_queue_jobs_on_active_job_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_jobs_on_active_job_id ON public.solid_queue_jobs USING btree (active_job_id);


--
-- Name: index_solid_queue_jobs_on_class_name; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_jobs_on_class_name ON public.solid_queue_jobs USING btree (class_name);


--
-- Name: index_solid_queue_jobs_on_finished_at; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_jobs_on_finished_at ON public.solid_queue_jobs USING btree (finished_at);


--
-- Name: index_solid_queue_pauses_on_queue_name; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_pauses_on_queue_name ON public.solid_queue_pauses USING btree (queue_name);


--
-- Name: index_solid_queue_poll_all; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_poll_all ON public.solid_queue_ready_executions USING btree (priority, job_id);


--
-- Name: index_solid_queue_poll_by_queue; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_poll_by_queue ON public.solid_queue_ready_executions USING btree (queue_name, priority, job_id);


--
-- Name: index_solid_queue_processes_on_last_heartbeat_at; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_processes_on_last_heartbeat_at ON public.solid_queue_processes USING btree (last_heartbeat_at);


--
-- Name: index_solid_queue_processes_on_name_and_supervisor_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_processes_on_name_and_supervisor_id ON public.solid_queue_processes USING btree (name, supervisor_id);


--
-- Name: index_solid_queue_processes_on_supervisor_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_processes_on_supervisor_id ON public.solid_queue_processes USING btree (supervisor_id);


--
-- Name: index_solid_queue_ready_executions_on_job_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_ready_executions_on_job_id ON public.solid_queue_ready_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_job_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_job_id ON public.solid_queue_recurring_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_task_key_and_run_at; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_task_key_and_run_at ON public.solid_queue_recurring_executions USING btree (task_key, run_at);


--
-- Name: index_solid_queue_recurring_tasks_on_key; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_recurring_tasks_on_key ON public.solid_queue_recurring_tasks USING btree (key);


--
-- Name: index_solid_queue_recurring_tasks_on_static; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_recurring_tasks_on_static ON public.solid_queue_recurring_tasks USING btree (static);


--
-- Name: index_solid_queue_scheduled_executions_on_job_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_scheduled_executions_on_job_id ON public.solid_queue_scheduled_executions USING btree (job_id);


--
-- Name: index_solid_queue_semaphores_on_expires_at; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_semaphores_on_expires_at ON public.solid_queue_semaphores USING btree (expires_at);


--
-- Name: index_solid_queue_semaphores_on_key; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_solid_queue_semaphores_on_key ON public.solid_queue_semaphores USING btree (key);


--
-- Name: index_solid_queue_semaphores_on_key_and_value; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_solid_queue_semaphores_on_key_and_value ON public.solid_queue_semaphores USING btree (key, value);


--
-- Name: index_stock_batches_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_stock_batches_on_product_id ON public.stock_batches USING btree (product_id);


--
-- Name: index_stock_batches_on_vendor_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_stock_batches_on_vendor_id ON public.stock_batches USING btree (vendor_id);


--
-- Name: index_stock_batches_on_vendor_purchase_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_stock_batches_on_vendor_purchase_id ON public.stock_batches USING btree (vendor_purchase_id);


--
-- Name: index_stock_movements_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_stock_movements_on_product_id ON public.stock_movements USING btree (product_id);


--
-- Name: index_sub_agents_on_aadhar_no; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_sub_agents_on_aadhar_no ON public.sub_agents USING btree (aadhar_no);


--
-- Name: index_sub_agents_on_email; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_sub_agents_on_email ON public.sub_agents USING btree (email);


--
-- Name: index_sub_agents_on_mobile; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_sub_agents_on_mobile ON public.sub_agents USING btree (mobile);


--
-- Name: index_sub_agents_on_pan_no; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_sub_agents_on_pan_no ON public.sub_agents USING btree (pan_no);


--
-- Name: index_subscription_templates_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_subscription_templates_on_customer_id ON public.subscription_templates USING btree (customer_id);


--
-- Name: index_subscription_templates_on_delivery_person_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_subscription_templates_on_delivery_person_id ON public.subscription_templates USING btree (delivery_person_id);


--
-- Name: index_subscription_templates_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_subscription_templates_on_product_id ON public.subscription_templates USING btree (product_id);


--
-- Name: index_system_settings_on_key; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_system_settings_on_key ON public.system_settings USING btree (key);


--
-- Name: index_user_roles_on_name; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_user_roles_on_name ON public.user_roles USING btree (name);


--
-- Name: index_users_on_aadhar_no; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_users_on_aadhar_no ON public.users USING btree (aadhar_no);


--
-- Name: index_users_on_authenticatable; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_users_on_authenticatable ON public.users USING btree (authenticatable_type, authenticatable_id);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_deleted_at; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_users_on_deleted_at ON public.users USING btree (deleted_at);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_employee_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_users_on_employee_id ON public.users USING btree (employee_id);


--
-- Name: index_users_on_is_active; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_users_on_is_active ON public.users USING btree (is_active);


--
-- Name: index_users_on_mobile; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_users_on_mobile ON public.users USING btree (mobile);


--
-- Name: index_users_on_pan_no; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_users_on_pan_no ON public.users USING btree (pan_no);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_role; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_users_on_role ON public.users USING btree (role);


--
-- Name: index_users_on_status; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_users_on_status ON public.users USING btree (status);


--
-- Name: index_users_on_unlock_token; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_users_on_unlock_token ON public.users USING btree (unlock_token);


--
-- Name: index_users_on_user_type; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_users_on_user_type ON public.users USING btree (user_type);


--
-- Name: index_vendor_invoices_on_invoice_number; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_vendor_invoices_on_invoice_number ON public.vendor_invoices USING btree (invoice_number);


--
-- Name: index_vendor_invoices_on_share_token; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_vendor_invoices_on_share_token ON public.vendor_invoices USING btree (share_token);


--
-- Name: index_vendor_invoices_on_vendor_purchase_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_vendor_invoices_on_vendor_purchase_id ON public.vendor_invoices USING btree (vendor_purchase_id);


--
-- Name: index_vendor_payments_on_vendor_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_vendor_payments_on_vendor_id ON public.vendor_payments USING btree (vendor_id);


--
-- Name: index_vendor_payments_on_vendor_purchase_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_vendor_payments_on_vendor_purchase_id ON public.vendor_payments USING btree (vendor_purchase_id);


--
-- Name: index_vendor_purchase_items_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_vendor_purchase_items_on_product_id ON public.vendor_purchase_items USING btree (product_id);


--
-- Name: index_vendor_purchase_items_on_vendor_purchase_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_vendor_purchase_items_on_vendor_purchase_id ON public.vendor_purchase_items USING btree (vendor_purchase_id);


--
-- Name: index_vendor_purchases_on_vendor_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_vendor_purchases_on_vendor_id ON public.vendor_purchases USING btree (vendor_id);


--
-- Name: index_wallet_transactions_on_customer_wallet_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_wallet_transactions_on_customer_wallet_id ON public.wallet_transactions USING btree (customer_wallet_id);


--
-- Name: index_wallet_transactions_on_reference_number; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE UNIQUE INDEX index_wallet_transactions_on_reference_number ON public.wallet_transactions USING btree (reference_number);


--
-- Name: index_wallet_transactions_on_transaction_type; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_wallet_transactions_on_transaction_type ON public.wallet_transactions USING btree (transaction_type);


--
-- Name: index_wishlists_on_customer_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_wishlists_on_customer_id ON public.wishlists USING btree (customer_id);


--
-- Name: index_wishlists_on_product_id; Type: INDEX; Schema: public; Owner: marali_sante_user
--

CREATE INDEX index_wishlists_on_product_id ON public.wishlists USING btree (product_id);


--
-- Name: milk_subscriptions fk_milk_subscriptions_delivery_person; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_subscriptions
    ADD CONSTRAINT fk_milk_subscriptions_delivery_person FOREIGN KEY (delivery_person_id) REFERENCES public.delivery_people(id);


--
-- Name: subscription_templates fk_rails_0427a5a8f5; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.subscription_templates
    ADD CONSTRAINT fk_rails_0427a5a8f5 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: booking_invoices fk_rails_0588ce0fe5; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_invoices
    ADD CONSTRAINT fk_rails_0588ce0fe5 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: invoice_items fk_rails_0c6e1fd09e; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT fk_rails_0c6e1fd09e FOREIGN KEY (milk_delivery_task_id) REFERENCES public.milk_delivery_tasks(id);


--
-- Name: stock_batches fk_rails_0fd8722280; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stock_batches
    ADD CONSTRAINT fk_rails_0fd8722280 FOREIGN KEY (vendor_purchase_id) REFERENCES public.vendor_purchases(id);


--
-- Name: sale_items fk_rails_10aa153cb0; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_10aa153cb0 FOREIGN KEY (booking_id) REFERENCES public.bookings(id);


--
-- Name: referrals fk_rails_143e21be26; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT fk_rails_143e21be26 FOREIGN KEY (affiliate_id) REFERENCES public.affiliates(id);


--
-- Name: wishlists fk_rails_18bd87f3b0; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.wishlists
    ADD CONSTRAINT fk_rails_18bd87f3b0 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: bookings fk_rails_1a839bd564; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_1a839bd564 FOREIGN KEY (delivery_person_id) REFERENCES public.delivery_people(id);


--
-- Name: vendor_purchase_items fk_rails_1d0b180fcb; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_purchase_items
    ADD CONSTRAINT fk_rails_1d0b180fcb FOREIGN KEY (vendor_purchase_id) REFERENCES public.vendor_purchases(id);


--
-- Name: booking_schedules fk_rails_1de48ebd18; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_schedules
    ADD CONSTRAINT fk_rails_1de48ebd18 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: invoice_items fk_rails_25bf3d2c5e; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT fk_rails_25bf3d2c5e FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);


--
-- Name: device_tokens fk_rails_287313072c; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT fk_rails_287313072c FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: referrals fk_rails_2a86f7c55b; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT fk_rails_2a86f7c55b FOREIGN KEY (referring_customer_id) REFERENCES public.customers(id);


--
-- Name: vendor_purchase_items fk_rails_2b2646ec33; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_purchase_items
    ADD CONSTRAINT fk_rails_2b2646ec33 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: stock_batches fk_rails_30af726acb; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stock_batches
    ADD CONSTRAINT fk_rails_30af726acb FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: bookings fk_rails_30b4781a51; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_30b4781a51 FOREIGN KEY (franchise_id) REFERENCES public.franchises(id);


--
-- Name: solid_queue_recurring_executions fk_rails_318a5533ed; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT fk_rails_318a5533ed FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: milk_delivery_tasks fk_rails_3630bcf24a; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_delivery_tasks
    ADD CONSTRAINT fk_rails_3630bcf24a FOREIGN KEY (subscription_id) REFERENCES public.milk_subscriptions(id);


--
-- Name: product_ratings fk_rails_36795236ae; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_ratings
    ADD CONSTRAINT fk_rails_36795236ae FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: milk_delivery_tasks fk_rails_390b1646ed; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_delivery_tasks
    ADD CONSTRAINT fk_rails_390b1646ed FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: solid_queue_failed_executions fk_rails_39bbc7a631; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT fk_rails_39bbc7a631 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: client_requests fk_rails_3d32864cfc; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.client_requests
    ADD CONSTRAINT fk_rails_3d32864cfc FOREIGN KEY (assignee_id) REFERENCES public.users(id);


--
-- Name: vendor_payments fk_rails_3d8456966c; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_payments
    ADD CONSTRAINT fk_rails_3d8456966c FOREIGN KEY (vendor_id) REFERENCES public.vendors(id);


--
-- Name: franchises fk_rails_41d1977e7e; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.franchises
    ADD CONSTRAINT fk_rails_41d1977e7e FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: wishlists fk_rails_4224d8f53b; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.wishlists
    ADD CONSTRAINT fk_rails_4224d8f53b FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: bookings fk_rails_469339cd03; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_469339cd03 FOREIGN KEY (store_id) REFERENCES public.stores(id);


--
-- Name: delivery_rules fk_rails_495c599380; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.delivery_rules
    ADD CONSTRAINT fk_rails_495c599380 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: milk_subscriptions fk_rails_4b4fb0c9b4; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_subscriptions
    ADD CONSTRAINT fk_rails_4b4fb0c9b4 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: subscription_templates fk_rails_4cd084b669; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.subscription_templates
    ADD CONSTRAINT fk_rails_4cd084b669 FOREIGN KEY (delivery_person_id) REFERENCES public.delivery_people(id);


--
-- Name: solid_queue_blocked_executions fk_rails_4cd34e2228; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT fk_rails_4cd34e2228 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: product_reviews fk_rails_4d29a9c00a; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_reviews
    ADD CONSTRAINT fk_rails_4d29a9c00a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notes fk_rails_65a5c39deb; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT fk_rails_65a5c39deb FOREIGN KEY (created_by_user_id) REFERENCES public.users(id);


--
-- Name: customer_wallets fk_rails_67b1f56e66; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_wallets
    ADD CONSTRAINT fk_rails_67b1f56e66 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: invoice_items fk_rails_72ed60e62c; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT fk_rails_72ed60e62c FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: referrals fk_rails_77c18d42bf; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT fk_rails_77c18d42bf FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: customer_addresses fk_rails_79041ef784; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_addresses
    ADD CONSTRAINT fk_rails_79041ef784 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: subscription_templates fk_rails_7cbefbc65a; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.subscription_templates
    ADD CONSTRAINT fk_rails_7cbefbc65a FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: vendor_purchases fk_rails_7dbe9a831a; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_purchases
    ADD CONSTRAINT fk_rails_7dbe9a831a FOREIGN KEY (vendor_id) REFERENCES public.vendors(id);


--
-- Name: milk_delivery_tasks fk_rails_7f5c180cc8; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_delivery_tasks
    ADD CONSTRAINT fk_rails_7f5c180cc8 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: solid_queue_ready_executions fk_rails_81fcbd66af; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT fk_rails_81fcbd66af FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: bookings fk_rails_94a0a341bb; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_94a0a341bb FOREIGN KEY (booking_schedule_id) REFERENCES public.booking_schedules(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: solid_queue_claimed_executions fk_rails_9cfe4d4944; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT fk_rails_9cfe4d4944 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: product_reviews fk_rails_9dcee7d533; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_reviews
    ADD CONSTRAINT fk_rails_9dcee7d533 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: vendor_invoices fk_rails_a2e0d1751f; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_invoices
    ADD CONSTRAINT fk_rails_a2e0d1751f FOREIGN KEY (vendor_purchase_id) REFERENCES public.vendor_purchases(id);


--
-- Name: product_reviews fk_rails_a6af267e3d; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_reviews
    ADD CONSTRAINT fk_rails_a6af267e3d FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: device_tokens fk_rails_a6eff83e14; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT fk_rails_a6eff83e14 FOREIGN KEY (delivery_person_id) REFERENCES public.delivery_people(id);


--
-- Name: milk_delivery_tasks fk_rails_aafb5e9feb; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_delivery_tasks
    ADD CONSTRAINT fk_rails_aafb5e9feb FOREIGN KEY (delivery_person_id) REFERENCES public.delivery_people(id);


--
-- Name: booking_schedules fk_rails_bf34e93579; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_schedules
    ADD CONSTRAINT fk_rails_bf34e93579 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: client_requests fk_rails_bf4af15099; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.client_requests
    ADD CONSTRAINT fk_rails_bf4af15099 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: solid_queue_scheduled_executions fk_rails_c4316f352d; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT fk_rails_c4316f352d FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: product_ratings fk_rails_cc19464c64; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_ratings
    ADD CONSTRAINT fk_rails_cc19464c64 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: customer_formats fk_rails_cec20eb18b; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_formats
    ADD CONSTRAINT fk_rails_cec20eb18b FOREIGN KEY (delivery_person_id) REFERENCES public.delivery_people(id);


--
-- Name: product_ratings fk_rails_d174ea1e32; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.product_ratings
    ADD CONSTRAINT fk_rails_d174ea1e32 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: customer_formats fk_rails_d1c53afd32; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_formats
    ADD CONSTRAINT fk_rails_d1c53afd32 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: sale_items fk_rails_d6e0e81317; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_d6e0e81317 FOREIGN KEY (stock_batch_id) REFERENCES public.stock_batches(id);


--
-- Name: customer_formats fk_rails_d8a77fd5fc; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.customer_formats
    ADD CONSTRAINT fk_rails_d8a77fd5fc FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: wallet_transactions fk_rails_dc5903e62b; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT fk_rails_dc5903e62b FOREIGN KEY (customer_wallet_id) REFERENCES public.customer_wallets(id);


--
-- Name: stock_movements fk_rails_deb37fa2ee; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT fk_rails_deb37fa2ee FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: milk_subscriptions fk_rails_e110a3862f; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.milk_subscriptions
    ADD CONSTRAINT fk_rails_e110a3862f FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: notifications fk_rails_e82fd73b00; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_e82fd73b00 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: sale_items fk_rails_ee606308b2; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_ee606308b2 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: pending_amounts fk_rails_f63a5d559b; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.pending_amounts
    ADD CONSTRAINT fk_rails_f63a5d559b FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: vendor_payments fk_rails_fa51839ac6; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.vendor_payments
    ADD CONSTRAINT fk_rails_fa51839ac6 FOREIGN KEY (vendor_purchase_id) REFERENCES public.vendor_purchases(id);


--
-- Name: products fk_rails_fb915499a4; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_fb915499a4 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: booking_invoices fk_rails_fd3dea094d; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.booking_invoices
    ADD CONSTRAINT fk_rails_fd3dea094d FOREIGN KEY (booking_id) REFERENCES public.bookings(id);


--
-- Name: stock_batches fk_rails_fd8d4dc083; Type: FK CONSTRAINT; Schema: public; Owner: marali_sante_user
--

ALTER TABLE ONLY public.stock_batches
    ADD CONSTRAINT fk_rails_fd8d4dc083 FOREIGN KEY (vendor_id) REFERENCES public.vendors(id);


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES TO marali_sante_user;


--
-- Name: DEFAULT PRIVILEGES FOR TYPES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TYPES TO marali_sante_user;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS TO marali_sante_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES TO marali_sante_user;


--
-- PostgreSQL database dump complete
--

\unrestrict CQmTajPxHeTjdUzdMB4tzkF3gx5ZJtC4dDG1I0DqsijuozRMypUN9PnXwIEEJyW

