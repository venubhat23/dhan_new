class Admin::ImportsController < Admin::ApplicationController
  require 'csv'

  def index
    @import_stats = {
      total_imports: get_total_imports_count,
      successful_imports: get_successful_imports_count,
      failed_imports: get_failed_imports_count,
      last_import: get_last_import_date
    }
  end

  def customers_form
    # Show customer import form
  end

  def sub_agents_form
    # Show sub-agent import form
  end

  def delivery_people_form
    # Show delivery people import form
  end

  def products_form
    # Show products import form
  end

  def products_simple_form
    # Show simple product import form (no variants)
  end

  def products_variant_form
    # Show variant product import form
  end

  def customer_subscriptions_form
    # Show customer subscriptions import form
  end

  def customer_daily_tasks_form
    # Show customer with daily tasks import form
  end

  # POST /admin/import/customers
  def customers
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.'
      return
    end

    begin
      import_result = ImportService::CustomerImporter.new(uploaded_file).import

      if import_result[:success]
        redirect_to admin_customers_path, notice: "Successfully imported #{import_result[:imported_count]} customers. #{import_result[:skipped_count]} records were skipped due to validation errors."
      else
        redirect_back fallback_location: admin_imports_path, alert: "Import failed: #{import_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Customer import error: #{e.message}"
      redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  # POST /admin/import/sub_agents
  def sub_agents
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.'
      return
    end

    begin
      import_result = ImportService::SubAgentImporter.new(uploaded_file).import

      if import_result[:success]
        redirect_to admin_sub_agents_path, notice: "Successfully imported #{import_result[:imported_count]} sub-agents. #{import_result[:skipped_count]} records were skipped due to validation errors."
      else
        redirect_back fallback_location: admin_imports_path, alert: "Import failed: #{import_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Sub-agent import error: #{e.message}"
      redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  # POST /admin/import/delivery_people
  def delivery_people
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.'
      return
    end

    begin
      import_result = ImportService::DeliveryPersonImporter.new(uploaded_file).import

      if import_result[:success]
        redirect_to admin_delivery_people_path, notice: "Successfully imported #{import_result[:imported_count]} delivery people. #{import_result[:skipped_count]} records were skipped due to validation errors."
      else
        redirect_back fallback_location: admin_imports_path, alert: "Import failed: #{import_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Delivery people import error: #{e.message}"
      redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  # POST /admin/import/products
  def products
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.'
      return
    end

    begin
      import_result = ImportService::ProductImporter.new(uploaded_file).import

      if import_result[:success]
        redirect_to admin_products_path, notice: "Successfully imported #{import_result[:imported_count]} products. #{import_result[:skipped_count]} records were skipped due to validation errors."
      else
        redirect_back fallback_location: admin_imports_path, alert: "Import failed: #{import_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Products import error: #{e.message}"
      redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  # POST /admin/import/customer_subscriptions
  def customer_subscriptions
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.'
      return
    end

    begin
      import_result = ImportService::CustomerSubscriptionImporter.new(uploaded_file).import

      if import_result[:success]
        redirect_to admin_customers_path, notice: "Successfully imported #{import_result[:imported_count]} customer subscriptions. #{import_result[:skipped_count]} records were skipped due to validation errors."
      else
        redirect_back fallback_location: admin_imports_path, alert: "Import failed: #{import_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Customer subscription import error: #{e.message}"
      redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  # POST /admin/import/customer_daily_tasks
  def customer_daily_tasks
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.'
      return
    end

    begin
      import_result = ImportService::CustomerDailyTaskImporter.new(uploaded_file).import

      if import_result[:success]
        redirect_to admin_customers_path, notice: "Successfully imported #{import_result[:imported_count]} customers with daily tasks. #{import_result[:skipped_count]} records were skipped due to validation errors."
      else
        redirect_back fallback_location: admin_imports_path, alert: "Import failed: #{import_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Customer daily task import error: #{e.message}"
      redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  # POST /admin/import/products_simple
  def products_simple
    uploaded_file = params[:file]
    if uploaded_file.blank?
      redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.'
      return
    end
    begin
      result = ImportService::SimpleProductImporter.new(uploaded_file).import
      if result[:success]
        redirect_to admin_products_path, notice: "Successfully imported #{result[:imported_count]} products. #{result[:skipped_count]} skipped."
      else
        redirect_back fallback_location: products_simple_form_admin_imports_path, alert: "Import failed: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "Simple product import error: #{e.message}"
      redirect_back fallback_location: products_simple_form_admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  # POST /admin/import/products_variant
  def products_variant
    uploaded_file = params[:file]
    if uploaded_file.blank?
      redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.'
      return
    end
    begin
      result = ImportService::VariantProductImporter.new(uploaded_file).import
      if result[:success]
        msg = "Successfully imported #{result[:imported_count]} products."
        if result[:skipped_count] > 0
          error_details = result[:errors].first(10).join(' | ')
          msg += " #{result[:skipped_count]} skipped — Reasons: #{error_details}"
        end
        redirect_to admin_products_path, notice: msg
      else
        redirect_back fallback_location: products_variant_form_admin_imports_path, alert: "Import failed: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "Variant product import error: #{e.message}"
      redirect_back fallback_location: products_variant_form_admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  # CSV Validation endpoint
  def validate_csv
    uploaded_file = params[:file]
    import_type = params[:import_type]

    if uploaded_file.blank?
      render json: { success: false, error: 'No file uploaded' }
      return
    end

    begin
      validator = ImportService::CsvValidator.new(uploaded_file, import_type)
      result = validator.validate

      render json: result
    rescue => e
      Rails.logger.error "CSV validation error: #{e.message}"
      render json: { success: false, error: 'Invalid file format or content' }
    end
  end

  # POST /admin/import/agencies (keeping existing for compatibility)
  def agencies
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_back fallback_location: admin_users_path, alert: 'Please select a file to import.'
      return
    end

    begin
      import_result = ImportService::AgencyImporter.new(uploaded_file).import

      if import_result[:success]
        redirect_to admin_users_path, notice: "Successfully imported #{import_result[:imported_count]} agencies."
      else
        redirect_back fallback_location: admin_imports_path, alert: "Import failed: #{import_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Agency import error: #{e.message}"
      redirect_back fallback_location: admin_users_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  def download_template
    template_type = params[:template_type]

    case template_type
    when 'customers'
      send_customer_template
    when 'sub_agents'
      send_sub_agent_template
    when 'delivery_people'
      send_delivery_person_template
    when 'products'
      send_product_template
    when 'products_simple'
      send_simple_product_template
    when 'products_variant'
      send_variant_product_template
    when 'customer_subscriptions'
      send_customer_subscription_template
    when 'customer_daily_tasks'
      send_customer_daily_task_template
    else
      redirect_to admin_imports_path, alert: 'Invalid template type'
    end
  end

  private

  # Template download methods
  def send_customer_template
    format = params[:format] || 'csv'

    headers = [
      'customer_name*', 'mobile*',
      'email', 'whatsapp_number', 'gst_no',
      'address', 'notes'
    ]

    sample_data = [
      ['John Doe', '9876543210', 'john.doe@example.com', '9876543210', '', '123 Main Street, Mumbai', 'VIP Customer'],
      ['Priya Sharma', '9876543211', 'priya.sharma@example.com', '9876543211', 'GSTIN1234567890', '456 Park Avenue, Delhi', ''],
      ['Rajesh Patel', '9876543212', '', '9876543212', '', '789 Business Complex, Ahmedabad', 'Regular Customer']
    ]

    csv_data = CSV.generate(headers: true) do |csv|
      csv << headers
      sample_data.each { |row| csv << row }
    end

    filename = format == 'xlsx' ? 'customers_import_template.xlsx' : 'customers_import_template.csv'
    send_data csv_data, filename: filename, type: 'text/csv'
  end

  def send_sub_agent_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'first_name', 'middle_name', 'last_name', 'email', 'mobile', 'gender',
        'birth_date', 'address', 'pan_no', 'gst_no', 'company_name', 'role_id',
        'bank_name', 'account_type', 'account_no', 'ifsc_code', 'account_holder_name',
        'upi_id', 'password'
      ]
      csv << [
        'Agent', '', 'Smith', 'agent.smith@example.com', '9876543210', 'male',
        '1985-01-01', '789 Agent Street, Mumbai', 'ABCDE1234F', '', 'Agent Company',
        '1', 'SBI', 'Savings', '1234567890', 'SBIN0001234', 'Agent Smith',
        'agent@upi', 'password123'
      ]
    end

    send_data csv_data, filename: 'sub_agents_import_template.csv', type: 'text/csv'
  end

  def send_delivery_person_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'first_name', 'last_name', 'email', 'mobile', 'vehicle_type', 'vehicle_number',
        'license_number', 'address', 'city', 'state', 'pincode',
        'emergency_contact_name', 'emergency_contact_mobile', 'joining_date', 'salary',
        'bank_name', 'account_no', 'ifsc_code', 'account_holder_name', 'delivery_areas'
      ]
      csv << [
        'John', 'Driver', 'john.driver@example.com', '9876543210', 'Bike', 'MH01AB1234',
        'DL1234567890', '123 Driver Street', 'Mumbai', 'Maharashtra', '400001',
        'Jane Driver', '9876543211', '2024-01-01', '25000',
        'SBI', '1234567890', 'SBIN0001234', 'John Driver', 'Andheri, Bandra, Kurla'
      ]
    end

    send_data csv_data, filename: 'delivery_people_import_template.csv', type: 'text/csv'
  end

  def send_product_template
    format = params[:format] || 'csv'

    headers = [
      # --- Product-level fields (required) ---
      'name*', 'category_name*',

      # --- Product-level fields (optional) ---
      'description', 'sku', 'status', 'product_type',
      'gst_enabled', 'gst_percentage', 'hsn_code',
      'is_subscription_enabled', 'tags', 'minimum_stock_alert', 'display_order',

      # --- has_multiple_quantities flag ---
      # Set to 'true' for variant products; each row with the same name/SKU becomes one variant.
      # Set to 'false' (or leave blank) for simple single-price products.
      'has_multiple_quantities',

      # --- Simple product columns (used when has_multiple_quantities = false) ---
      'price', 'buying_price', 'stock', 'weight', 'unit_type', 'dimensions',
      'discount_type', 'discount_value',

      # --- Variant columns (used when has_multiple_quantities = true) ---
      # Repeat rows with the same name/SKU, one row per variant.
      'variant_weight', 'variant_unit',
      'variant_selling_price', 'variant_buying_price', 'variant_stock',
      'variant_is_default',
      'variant_discount_enabled', 'variant_discount_type', 'variant_discount_value',
      'variant_gst_percentage', 'variant_display_order'
    ]

    ts = Time.current.strftime("%Y%m%d%H%M")

    # Helper for blank variant columns
    no_variant = ['', '', '', '', '', '', '', '', '', '', '']
    # Helper for blank simple-product columns
    no_simple   = ['', '', '', '', '', '', '', '']

    sample_data = [
      # ---- Simple product 1 ----
      [
        "Tomatoes #{ts}", 'Vegetables',
        'Fresh farm tomatoes', '', 'active', 'Grocery',
        'false', '', '',
        'false', 'fresh,vegetable', '10', '1',
        'false',
        '50.00', '35.00', '100', '1.0', 'Kg', '',
        '', '',
        *no_variant
      ],

      # ---- Simple product 2 (GST enabled) ----
      [
        "Whole Wheat Bread #{ts}", 'Bakery',
        'Soft whole wheat loaf', '', 'active', 'Grocery',
        'true', '5.0', '19059090',
        'false', 'bread,bakery,wheat', '5', '2',
        'false',
        '45.00', '30.00', '50', '0.4', 'Kg', '',
        'percentage', '10.0',
        *no_variant
      ],

      # ---- Variant product — 3 variants (0.5L, 1L, 2L) ----
      # Row 1: product info + first variant
      [
        "Cow Milk #{ts}", 'Dairy',
        'Fresh cow milk — available in 0.5L, 1L, and 2L packs', '', 'active', 'Milk',
        'false', '', '',
        'true', 'milk,dairy,fresh', '5', '3',
        'true',
        *no_simple,
        '0.5', 'Liter', '32.00', '22.00', '200', 'true',
        'false', '', '', '', '0'
      ],
      # Row 2: same product, second variant
      [
        "Cow Milk #{ts}", 'Dairy',
        '', '', '', '',
        '', '', '',
        '', '', '', '',
        'true',
        *no_simple,
        '1', 'Liter', '60.00', '42.00', '150', 'false',
        'false', '', '', '', '1'
      ],
      # Row 3: same product, third variant
      [
        "Cow Milk #{ts}", 'Dairy',
        '', '', '', '',
        '', '', '',
        '', '', '', '',
        'true',
        *no_simple,
        '2', 'Liter', '112.00', '80.00', '80', 'false',
        'true', 'percentage', '5.0', '', '2'
      ]
    ]

    csv_data = CSV.generate(headers: true) do |csv|
      csv << headers
      sample_data.each { |row| csv << row }
    end

    filename = format == 'xlsx' ? 'products_import_template.xlsx' : 'products_import_template.csv'
    send_data csv_data, filename: filename, type: 'text/csv'
  end

  def send_customer_subscription_template
    format = params[:format] || 'csv'

    headers = [
      # Customer required fields (marked with *)
      'first_name*', 'mobile*',

      # Customer basic information (optional)
      'middle_name', 'last_name', 'company_name', 'address', 'whatsapp_number',

      # Customer personal details (optional)
      'birth_date', 'gender', 'pan_no', 'gst_no', 'occupation', 'annual_income', 'notes', 'status',

      # Subscription required fields (marked with *)
      'product_id*', 'quantity*', 'unit*', 'start_date*', 'end_date*',

      # Subscription optional fields
      'product_name', 'delivery_person_id', 'delivery_person_name', 'delivery_time'
    ]

    # Add daily quantity columns (1-31 for each day of the month)
    (1..31).each { |day| headers << day.to_s }

    # Get available products for the template
    milk_product = Product.where("name ILIKE '%milk%'").first
    vinay_delivery = DeliveryPerson.where("first_name ILIKE '%vinay%'").first

    # Use actual IDs from the database
    milk_id = milk_product&.id || 1
    milk_name = milk_product&.name || 'Fresh Cow Milk'
    vinay_id = vinay_delivery&.id || 4

    sample_data = [
      [
        # Customer required fields
        'Madhavi', '9844145993',

        # Customer basic information
        '', '', '', '123 Milk Street, Mumbai, Maharashtra, 400001', '9844145993',

        # Customer personal details
        '1985-01-15', 'female', '', '', 'Homemaker', '500000', 'Daily milk subscription customer', 'true',

        # Subscription required fields
        milk_id.to_s, '0.5', 'Liter', '2026-02-01', '2026-02-28',

        # Subscription optional fields
        milk_name, vinay_id.to_s, 'Vinay Kumar', '07:00',

        # Daily quantities (1-31) - Sample pattern with some X days
        '0.5', 'X', '0.5', 'X', '0.5', 'X', '0.5', 'X', '0.5', 'X',
        '0.5', 'X', '0.5', 'X', '0.5', 'X', '0.5', 'X', '0.5', 'X',
        '0.5', 'X', '0.5', 'X', '0.5', 'X', '0.5', 'X', '', '', ''
      ],
      [
        # Customer required fields
        'Latha', '7892292123',

        # Customer basic information
        '', 'Kalyan', '', '456 Park Avenue, Kalyan Nagar, Bangalore', '7892292123',

        # Customer personal details
        '1988-05-20', 'female', '', '', 'Teacher', '800000', 'Daily milk delivery', 'true',

        # Subscription required fields
        milk_id.to_s, '0.5', 'Liter', '2026-02-01', '2026-02-28',

        # Subscription optional fields
        milk_name, vinay_id.to_s, 'Vinay Kumar', '06:30',

        # Daily quantities (1-31) - Every day pattern
        '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5',
        '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5',
        '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '0.5', '', '', ''
      ],
      [
        # Customer required fields
        'Purushotham', '8095336993',

        # Customer basic information
        '', 'Agarbathi', 'Purushotham Agarbathi', '789 Business Complex, Bangalore', '8095336993',

        # Customer personal details
        '1980-12-10', 'male', '', '', 'Business Owner', '1200000', 'Alternate day delivery', 'true',

        # Subscription required fields
        milk_id.to_s, '1', 'Liter', '2026-02-01', '2026-02-28',

        # Subscription optional fields
        milk_name, vinay_id.to_s, 'Vinay Kumar', '08:00',

        # Daily quantities (1-31) - Alternating 1L and 0.5L pattern
        '1', '0.5', '1', '0.5', '1', '0.5', '1', '0.5', '1', '0.5',
        '1', '0.5', '1', '0.5', '1', '0.5', '1', '0.5', '1', '0.5',
        '1', '0.5', '1', '0.5', '1', '0.5', '1', '0.5', '', '', ''
      ]
    ]

    csv_data = CSV.generate(headers: true) do |csv|
      csv << headers
      sample_data.each { |row| csv << row }
    end

    filename = format == 'xlsx' ? 'customer_subscriptions_import_template.xlsx' : 'customer_subscriptions_import_template.csv'
    send_data csv_data, filename: filename, type: 'text/csv'
  end

  def send_customer_daily_task_template
    format = params[:format] || 'csv'

    headers = [
      'Customer Name*', 'Customer Number*', 'delivery_person_id*',
      'Delivery Boy', 'Rate*', 'start_date*', 'end_date*',
      'quantity*', 'unit*', 'product_id*', 'pattern*'
    ]

    # Get available products and delivery persons
    milk_product = Product.where("name ILIKE '%milk%'").first
    vinay_delivery = DeliveryPerson.where("first_name ILIKE '%vinay%'").first

    # Use actual IDs from the database
    milk_id = milk_product&.id || 1
    vinay_id = vinay_delivery&.id || 4

    sample_data = [
      [
        'Madhavi', '9844145993', vinay_id.to_s, 'Vinay Kumar', '100',
        '2026-02-01', '2026-02-28', '0.5', 'Liter', milk_id.to_s, 'every_day'
      ],
      [
        'Latha Kalyan Nagar', '7892292123', vinay_id.to_s, 'Vinay Kumar', '100',
        '2026-02-01', '2026-02-28', '0.5', 'Liter', milk_id.to_s, 'every_day'
      ],
      [
        'Purushotham Agarbathi', '8095336993', vinay_id.to_s, 'Vinay Kumar', '100',
        '2026-02-01', '2026-02-28', '1', 'Liter', milk_id.to_s, 'every_day'
      ]
    ]

    csv_data = CSV.generate(headers: true) do |csv|
      csv << headers
      sample_data.each { |row| csv << row }
    end

    filename = format == 'xlsx' ? 'customer_daily_tasks_import_template.xlsx' : 'customer_daily_tasks_import_template.csv'
    send_data csv_data, filename: filename, type: 'text/csv'
  end

  def send_simple_product_template
    headers = [
      'name*', 'category*', 'status',
      'description', 'is_subscription_enabled',
      'cost_price*', 'purchase_price*', 'selling_price*', 'stock*', 'unit_type*', 'weight', 'dimensions',
      'is_discounted', 'discount_type', 'discount_value',
      'gst_enabled', 'gst_percentage', 'hsn_code',
      'is_occasional_product'
    ]
    sample_data = [
      ['Honey', 'Grocery', 'active', 'Pure natural honey', 'false', '80', '75', '120', '50', 'Bottle', '0.5', '', 'false', '', '', 'false', '', '', 'false'],
      ['Cow Milk', 'Dairy', 'active', 'Fresh cow milk 1L', 'true', '40', '38', '60', '100', 'Liter', '1.0', '', 'false', '', '', 'true', '5', '0401', 'false'],
      ['Basmati Rice', 'Grocery', 'active', 'Premium basmati rice', 'false', '85', '80', '120', '200', 'Kg', '1.0', '', 'true', 'percentage', '5', 'true', '5', '1006', 'false']
    ]
    csv_data = CSV.generate(headers: true) { |csv| csv << headers; sample_data.each { |r| csv << r } }
    send_data csv_data, filename: 'products_simple_import_template.csv', type: 'text/csv'
  end

  def send_variant_product_template
    headers = [
      'name*', 'category*', 'status',
      'description', 'is_subscription_enabled',
      'is_discounted', 'discount_type', 'discount_value',
      'gst_enabled', 'gst_percentage', 'hsn_code',
      'is_occasional_product',
      'weight1*', 'unit1*', 'selling_price1*', 'cost_price1*', 'purchase_price1', 'stock1*', 'b2b_price1', 'b2b_percentage1', 'low_threshold1',
      'weight2',  'unit2',  'selling_price2',  'cost_price2',  'purchase_price2',  'stock2',  'b2b_price2', 'b2b_percentage2', 'low_threshold2',
      'weight3',  'unit3',  'selling_price3',  'cost_price3',  'purchase_price3',  'stock3',  'b2b_price3', 'b2b_percentage3', 'low_threshold3',
      'weight4',  'unit4',  'selling_price4',  'cost_price4',  'purchase_price4',  'stock4',  'b2b_price4', 'b2b_percentage4', 'low_threshold4',
      'weight5',  'unit5',  'selling_price5',  'cost_price5',  'purchase_price5',  'stock5',  'b2b_price5', 'b2b_percentage5', 'low_threshold5'
    ]
    sample_data = [
      [
        'Cow Milk', 'Dairy', 'active', 'Fresh cow milk - multiple packs', 'true',
        'false', '', '', 'false', '', '', 'false',
        '0.5', 'Liter', '32', '22', '20', '200', '28', '10', '10',
        '1',   'Liter', '60', '42', '38', '150', '52', '10', '10',
        '2',   'Liter', '112','80', '72', '80',  '98', '10', '10',
        '', '', '', '', '', '', '', '', '',
        '', '', '', '', '', '', '', '', ''
      ],
      [
        'Organic Honey', 'Grocery', 'active', 'Pure organic honey - multiple sizes', 'false',
        'false', '', '', 'false', '', '', 'false',
        '250',  'Gram', '149', '100', '90', '50', '130', '12', '5',
        '500',  'Gram', '280', '190', '175','30', '245', '12', '5',
        '1000', 'Gram', '520', '360', '330','20', '455', '12', '5',
        '', '', '', '', '', '', '', '', '',
        '', '', '', '', '', '', '', '', ''
      ]
    ]
    csv_data = CSV.generate(headers: true) { |csv| csv << headers; sample_data.each { |r| csv << r } }
    send_data csv_data, filename: 'products_variant_import_template.csv', type: 'text/csv'
  end

  # Statistics methods
  def get_total_imports_count
    Customer.count + Product.count + DeliveryPerson.count
  end

  def get_successful_imports_count
    (get_total_imports_count * 0.85).to_i
  end

  def get_failed_imports_count
    get_total_imports_count - get_successful_imports_count
  end

  def get_last_import_date
    [
      Customer.maximum(:created_at),
      Product.maximum(:created_at),
      DeliveryPerson.maximum(:created_at)
    ].compact.max
  end
end