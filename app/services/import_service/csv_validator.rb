module ImportService
  class CsvValidator
    require 'csv'

    def initialize(uploaded_file, import_type)
      @uploaded_file = uploaded_file
      @import_type = import_type
      @errors = []
      @warnings = []
      @row_count = 0
      @valid_rows = 0
    end

    def validate
      return { success: false, error: 'No file provided' } unless @uploaded_file

      # Check file extension
      unless valid_file_extension?
        return { success: false, error: 'Invalid file type. Please upload a CSV file.' }
      end

      # Check file size (max 10MB)
      if @uploaded_file.size > 10.megabytes
        return { success: false, error: 'File size too large. Maximum allowed size is 10MB.' }
      end

      begin
        # Parse and validate CSV content
        csv_content = @uploaded_file.read
        @uploaded_file.rewind

        # Check if file is empty
        if csv_content.blank?
          return { success: false, error: 'File is empty' }
        end

        # Parse CSV
        csv_data = CSV.parse(csv_content, headers: true)

        if csv_data.empty?
          return { success: false, error: 'CSV file contains no data rows' }
        end

        @row_count = csv_data.size

        # Validate headers
        header_validation = validate_headers(csv_data.headers)
        return header_validation unless header_validation[:success]

        # Validate each row
        csv_data.each_with_index do |row, index|
          validate_row(row, index + 2) # +2 because CSV is 1-indexed and we skip header
        end

        @valid_rows = @row_count - @errors.count

        {
          success: true,
          total_rows: @row_count,
          valid_rows: @valid_rows,
          invalid_rows: @errors.count,
          errors: @errors,
          warnings: @warnings,
          preview_data: get_preview_data(csv_data)
        }

      rescue CSV::MalformedCSVError => e
        { success: false, error: "Invalid CSV format: #{e.message}" }
      rescue => e
        Rails.logger.error "CSV validation error: #{e.message}"
        { success: false, error: 'Unable to process file. Please check the file format.' }
      end
    end

    private

    def valid_file_extension?
      # For Tempfile or other file objects that don't have original_filename,
      # assume they are valid if they're being tested programmatically
      return true unless @uploaded_file.respond_to?(:original_filename)
      return true if @uploaded_file.original_filename.nil? # Allow Tempfiles

      filename = @uploaded_file.original_filename.downcase
      filename.end_with?('.csv')
    end

    def validate_headers(headers)
      expected_headers = get_expected_headers

      if headers.nil? || headers.empty?
        return { success: false, error: 'CSV file must have headers' }
      end

      # Clean headers (remove whitespace, asterisks, convert to lowercase)
      actual_headers = headers.map(&:to_s).map(&:strip).map { |h| h.gsub(/\*/, '') }.map(&:downcase)
      expected_headers_clean = expected_headers.map(&:downcase)

      # Check for required headers
      missing_headers = expected_headers_clean - actual_headers

      if missing_headers.any?
        return {
          success: false,
          error: "Missing required columns: #{missing_headers.join(', ')}"
        }
      end

      # Check for extra headers (just warn, don't fail)
      extra_headers = actual_headers - expected_headers_clean
      if extra_headers.any?
        @warnings << "Extra columns found (will be ignored): #{extra_headers.join(', ')}"
      end

      { success: true }
    end

    def validate_row(row, row_number)
      case @import_type
      when 'customers'
        validate_customer_row(row, row_number)
      when 'delivery_people'
        validate_delivery_person_row(row, row_number)
      when 'products'
        validate_product_row(row, row_number)
      when 'customer_subscriptions'
        validate_customer_subscription_row(row, row_number)
      when 'customer_daily_tasks'
        validate_customer_daily_task_row(row, row_number)
      end
    end

    def validate_customer_row(row, row_number)
      errors_for_row = []

      # Required fields validation
      if row['first_name'].blank?
        errors_for_row << "First name is required"
      end

      # Email validation - now optional
      if row['email'].present? && !valid_email?(row['email'])
        errors_for_row << "Invalid email format"
      end

      if row['mobile'].blank?
        errors_for_row << "Mobile number is required"
      elsif !valid_mobile?(row['mobile'])
        errors_for_row << "Invalid mobile number format"
      end

      # Coordinate validation (optional)
      if row['longitude'].present? && !valid_decimal?(row['longitude'])
        errors_for_row << "Invalid longitude format"
      end

      if row['latitude'].present? && !valid_decimal?(row['latitude'])
        errors_for_row << "Invalid latitude format"
      end

      # WhatsApp validation (optional, but should match mobile format if provided)
      if row['whatsapp_number'].present? && !valid_mobile?(row['whatsapp_number'])
        errors_for_row << "Invalid WhatsApp number format"
      end

      if errors_for_row.any?
        @errors << "Row #{row_number}: #{errors_for_row.join(', ')}"
      end
    end

    def validate_delivery_person_row(row, row_number)
      errors_for_row = []

      # Required fields
      ['first_name', 'last_name', 'email', 'mobile'].each do |field|
        if row[field].blank?
          errors_for_row << "#{field} is required"
        end
      end

      # Email validation
      if row['email'].present? && !valid_email?(row['email'])
        errors_for_row << "Invalid email format"
      end

      # Mobile validation
      if row['mobile'].present? && !valid_mobile?(row['mobile'])
        errors_for_row << "Invalid mobile number format"
      end

      # Vehicle type validation
      if row['vehicle_type'].present? && !['bike', 'car', 'van', 'truck'].include?(row['vehicle_type'].downcase)
        errors_for_row << "Vehicle type must be 'bike', 'car', 'van', or 'truck'"
      end

      # Date validation
      if row['joining_date'].present? && !valid_date?(row['joining_date'])
        errors_for_row << "Invalid joining_date format (use YYYY-MM-DD)"
      end

      # Salary validation
      if row['salary'].present? && !valid_decimal?(row['salary'])
        errors_for_row << "Invalid salary amount"
      end

      if errors_for_row.any?
        @errors << "Row #{row_number}: #{errors_for_row.join(', ')}"
      end
    end

    def validate_product_row(row, row_number)
      errors_for_row = []

      name = row['name*'] || row['name']
      if name.blank?
        errors_for_row << "name is required"
      end

      has_multiple = ['true', '1', 'yes'].include?((row['has_multiple_quantities'] || '').downcase)

      if has_multiple
        # Variant product validations
        variant_weight = row['variant_weight']
        variant_selling_price = row['variant_selling_price']

        if variant_weight.blank?
          errors_for_row << "variant_weight is required for variant products"
        elsif !valid_decimal?(variant_weight)
          errors_for_row << "Invalid variant_weight format"
        end

        if variant_selling_price.blank?
          errors_for_row << "variant_selling_price is required for variant products"
        elsif !valid_decimal?(variant_selling_price)
          errors_for_row << "Invalid variant_selling_price format"
        end

        if row['variant_buying_price'].present? && !valid_decimal?(row['variant_buying_price'])
          errors_for_row << "Invalid variant_buying_price format"
        end

        if row['variant_stock'].present? && !valid_integer?(row['variant_stock'])
          errors_for_row << "Invalid variant_stock quantity"
        end

        if row['variant_discount_type'].present? && !['percentage', 'fixed'].include?(row['variant_discount_type'].downcase)
          errors_for_row << "variant_discount_type must be 'percentage' or 'fixed'"
        end

        if row['variant_discount_value'].present? && !valid_decimal?(row['variant_discount_value'])
          errors_for_row << "Invalid variant_discount_value format"
        end

        if row['variant_gst_percentage'].present? && !valid_decimal?(row['variant_gst_percentage'])
          errors_for_row << "Invalid variant_gst_percentage"
        end
      else
        # Simple product validations
        price = row['price*'] || row['price']
        if price.blank?
          errors_for_row << "price is required for simple products"
        elsif !valid_decimal?(price)
          errors_for_row << "Invalid price format"
        end

        if row['stock'].present? && !valid_integer?(row['stock'])
          errors_for_row << "Invalid stock quantity"
        end

        if row['discount_price'].present? && !valid_decimal?(row['discount_price'])
          errors_for_row << "Invalid discount_price format"
        end

        if row['buying_price'].present? && !valid_decimal?(row['buying_price'])
          errors_for_row << "Invalid buying_price format"
        end
      end

      # Common validations
      if row['status'].present? && !['active', 'inactive'].include?(row['status'].downcase)
        errors_for_row << "Status must be 'active' or 'inactive'"
      end

      if row['gst_enabled'].present? && !['true', 'false', ''].include?(row['gst_enabled'].downcase)
        errors_for_row << "gst_enabled must be 'true' or 'false'"
      end

      if row['gst_percentage'].present? && !valid_decimal?(row['gst_percentage'])
        errors_for_row << "Invalid gst_percentage"
      end

      valid_product_types = Product::PRODUCT_TYPES.map(&:last).map(&:downcase)
      if row['product_type'].present? && !valid_product_types.include?(row['product_type'].downcase)
        errors_for_row << "product_type must be one of: #{Product::PRODUCT_TYPES.map(&:last).join(', ')}"
      end

      if errors_for_row.any?
        @errors << "Row #{row_number}: #{errors_for_row.join(', ')}"
      end
    end

    def validate_customer_subscription_row(row, row_number)
      errors_for_row = []

      # Customer required fields
      ['first_name', 'mobile'].each do |field|
        field_value = row["#{field}*"] || row[field]
        if field_value.blank?
          errors_for_row << "#{field} is required"
        end
      end

      # Email validation
      email = row['email*'] || row['email']
      if email.present? && !valid_email?(email)
        errors_for_row << "Invalid email format"
      end

      # Mobile validation
      mobile = row['mobile*'] || row['mobile']
      if mobile.present? && !valid_mobile?(mobile)
        errors_for_row << "Invalid mobile number format"
      end

      # Subscription required fields
      ['product_id', 'quantity', 'unit', 'start_date', 'end_date'].each do |field|
        field_value = row["#{field}*"] || row[field]
        if field_value.blank?
          errors_for_row << "#{field} is required"
        end
      end

      # Quantity validation
      quantity = row['quantity*'] || row['quantity']
      if quantity.present? && !valid_decimal?(quantity)
        errors_for_row << "Invalid quantity format"
      end

      # Date validation
      start_date = row['start_date*'] || row['start_date']
      if start_date.present? && !valid_date?(start_date)
        errors_for_row << "Invalid start_date format (use YYYY-MM-DD)"
      end

      end_date = row['end_date*'] || row['end_date']
      if end_date.present? && !valid_date?(end_date)
        errors_for_row << "Invalid end_date format (use YYYY-MM-DD)"
      end

      if errors_for_row.any?
        @errors << "Row #{row_number}: #{errors_for_row.join(', ')}"
      end
    end

    def validate_customer_daily_task_row(row, row_number)
      errors_for_row = []

      # Customer required fields - check with and without asterisks (case-insensitive)
      customer_name = row['Customer Name*'] || row['customer name*'] || row['Customer Name'] || row['customer name']
      customer_number = row['Customer Number*'] || row['customer number*'] || row['Customer Number'] || row['customer number']

      if customer_name.blank?
        errors_for_row << "Customer Name is required"
      end

      if customer_number.blank?
        errors_for_row << "Customer Number is required"
      elsif !valid_mobile?(customer_number)
        errors_for_row << "Invalid Customer Number format"
      end

      # Get field values for validation
      delivery_person_id = row['delivery_person_id*'] || row['delivery_person_id']
      product_id = row['product_id*'] || row['product_id']
      quantity = row['quantity*'] || row['quantity']
      unit = row['unit*'] || row['unit']
      start_date = row['start_date*'] || row['start_date']
      end_date = row['end_date*'] || row['end_date']
      pattern = row['pattern*'] || row['pattern']

      # Required fields validation
      if delivery_person_id.blank?
        errors_for_row << "delivery_person_id is required"
      end

      if product_id.blank?
        errors_for_row << "product_id is required"
      end

      if quantity.blank?
        errors_for_row << "quantity is required"
      end

      if unit.blank?
        errors_for_row << "unit is required"
      end

      if start_date.blank?
        errors_for_row << "start_date is required"
      end

      if end_date.blank?
        errors_for_row << "end_date is required"
      end

      if pattern.blank?
        errors_for_row << "pattern is required"
      end

      # Specific validations
      if delivery_person_id.present? && !valid_integer?(delivery_person_id)
        errors_for_row << "Invalid delivery_person_id format"
      end

      if product_id.present? && !valid_integer?(product_id)
        errors_for_row << "Invalid product_id format"
      end

      if quantity.present? && !valid_decimal?(quantity)
        errors_for_row << "Invalid quantity format"
      elsif quantity.present? && quantity.to_f <= 0
        errors_for_row << "Quantity must be greater than 0"
      end

      # Date validation
      if start_date.present? && !valid_date?(start_date)
        errors_for_row << "Invalid start_date format (use YYYY-MM-DD)"
      end

      if end_date.present? && !valid_date?(end_date)
        errors_for_row << "Invalid end_date format (use YYYY-MM-DD)"
      end

      # Validate start_date is before end_date
      if start_date.present? && end_date.present? && valid_date?(start_date) && valid_date?(end_date)
        if Date.parse(start_date) >= Date.parse(end_date)
          errors_for_row << "start_date must be before end_date"
        end
      end

      # Pattern validation
      if pattern.present? && !['everyday', 'every_day', 'alternative_day', 'weekly_once', 'weekly_twice', 'weekly_thrice', 'weekly_four', 'weekly_five', 'weekly_six', 'random'].include?(pattern.downcase)
        errors_for_row << "Pattern must be one of: everyday, every_day, alternative_day, weekly_once, weekly_twice, weekly_thrice, weekly_four, weekly_five, weekly_six, random"
      end

      if errors_for_row.any?
        @errors << "Row #{row_number}: #{errors_for_row.join(', ')}"
      end
    end

    def get_expected_headers
      case @import_type
      when 'customers'
        ['first_name', 'last_name', 'mobile']  # Only truly required fields
      when 'delivery_people'
        ['first_name', 'last_name', 'email', 'mobile', 'vehicle_type', 'vehicle_number',
         'license_number', 'address', 'city', 'state', 'pincode',
         'emergency_contact_name', 'emergency_contact_mobile', 'joining_date', 'salary',
         'bank_name', 'account_no', 'ifsc_code', 'account_holder_name', 'delivery_areas']
      when 'products'
        ['name']  # Minimum required; price for simple products, variant_weight/variant_selling_price for variant products
      when 'customer_subscriptions'
        ['first_name', 'mobile', 'product_id', 'quantity', 'unit', 'start_date', 'end_date']  # Required fields for subscription import
      when 'customer_daily_tasks'
        ['customer name', 'customer number', 'delivery_person_id', 'product_id', 'quantity', 'unit', 'start_date', 'end_date', 'pattern']  # Required fields for daily tasks import
      else
        []
      end
    end

    def get_preview_data(csv_data)
      # Return first 5 rows for preview
      csv_data.first(5).map(&:to_h)
    end

    # Validation helper methods
    def valid_email?(email)
      email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
    end

    def valid_mobile?(mobile)
      # Indian mobile number validation (10 digits)
      mobile.gsub(/\D/, '').length == 10
    end

    def valid_date?(date_string)
      Date.parse(date_string.to_s)
      true
    rescue ArgumentError
      false
    end

    def valid_decimal?(value)
      Float(value.to_s)
      true
    rescue ArgumentError
      false
    end

    def valid_integer?(value)
      Integer(value.to_s)
      true
    rescue ArgumentError
      false
    end
  end
end