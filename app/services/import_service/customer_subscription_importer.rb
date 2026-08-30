module ImportService
  class CustomerSubscriptionImporter
    require 'csv'

    def initialize(uploaded_file)
      @uploaded_file = uploaded_file
      @imported_count = 0
      @skipped_count = 0
      @errors = []
    end

    def import
      return { success: false, error: 'No file provided' } unless @uploaded_file

      begin
        csv_content = @uploaded_file.read
        @uploaded_file.rewind

        csv_data = CSV.parse(csv_content, headers: true)

        # Validate CSV first
        validator = CsvValidator.new(@uploaded_file, 'customer_subscriptions')
        validation_result = validator.validate

        unless validation_result[:success]
          return { success: false, error: validation_result[:error] }
        end

        Customer.transaction do
          csv_data.each_with_index do |row, index|
            begin
              process_customer_subscription_row(row, index + 2)
            rescue => e
              @errors << "Row #{index + 2}: #{e.message}"
              @skipped_count += 1
            end
          end
        end

        {
          success: true,
          imported_count: @imported_count,
          skipped_count: @skipped_count,
          errors: @errors
        }

      rescue CSV::MalformedCSVError => e
        { success: false, error: "Invalid CSV format: #{e.message}" }
      rescue => e
        Rails.logger.error "Customer subscription import error: #{e.message}"
        { success: false, error: e.message }
      end
    end

    private

    def process_customer_subscription_row(row, row_number)
      # Customer data
      customer_params = {
        full_name: get_row_value(row, 'full_name') || [get_row_value(row, 'first_name'), get_row_value(row, 'middle_name'), get_row_value(row, 'last_name')].compact_blank.join(' ').presence,
        email: get_row_value(row, 'email'),
        mobile: get_row_value(row, 'mobile'),
        whatsapp_number: get_row_value(row, 'whatsapp_number'),
        address: get_row_value(row, 'address'),
        gender: get_row_value(row, 'gender'),
        birth_date: parse_date(get_row_value(row, 'birth_date')),
        pan_no: get_row_value(row, 'pan_no'),
        gst_no: get_row_value(row, 'gst_no'),
        company_name: get_row_value(row, 'company_name'),
        occupation: get_row_value(row, 'occupation'),
        annual_income: parse_decimal(get_row_value(row, 'annual_income')),
        notes: get_row_value(row, 'notes'),
        status: parse_boolean(get_row_value(row, 'status'), default: true)
      }

      # Check if customer already exists by email or mobile
      existing_customer = nil
      if customer_params[:email].present?
        existing_customer = Customer.find_by(email: customer_params[:email])
      end

      if existing_customer.nil? && customer_params[:mobile].present?
        existing_customer = Customer.find_by(mobile: customer_params[:mobile])
      end

      if existing_customer
        customer = existing_customer
      else
        customer = Customer.create!(customer_params)

        # Create User account for new customer with auto-generated password
        if customer.email.present?
          existing_user = User.find_by(email: customer.email, user_type: 'customer')
          unless existing_user
            generated_password = generate_secure_password(customer)

            # Store password in customer record
            customer.update!(auto_generated_password: generated_password)

            User.create!(
              first_name: customer.full_name.to_s.split(' ').first.presence || 'Customer',
              last_name: customer.full_name.to_s.split(' ')[1..-1]&.join(' ').presence || 'User',
              email: customer.email,
              mobile: customer.mobile,
              password: generated_password,
              password_confirmation: generated_password,
              user_type: 'customer',
              address: customer.address,
              city: 'Unknown',
              state: 'Unknown',
              pincode: '000000',
              country: 'India',
              status: true,
              is_active: true,
              is_verified: false
            )
          end
        end
      end

      # Find product and delivery person
      product = find_product(row, row_number)
      delivery_person = find_delivery_person(row, row_number)

      # Subscription data
      subscription_params = {
        customer_id: customer.id,
        product_id: product.id,
        delivery_person_id: delivery_person&.id,
        quantity: parse_decimal(get_row_value(row, 'quantity')),
        unit: get_row_value(row, 'unit') || 'Liter',
        start_date: parse_date(get_row_value(row, 'start_date')),
        end_date: parse_date(get_row_value(row, 'end_date')),
        delivery_time: get_row_value(row, 'delivery_time') || '07:00',
        is_active: true,
        status: 'active'
      }

      # Calculate total amount
      if product.price && subscription_params[:quantity]
        days_count = (subscription_params[:end_date] - subscription_params[:start_date]).to_i + 1
        subscription_params[:total_amount] = product.price * subscription_params[:quantity] * days_count
      end
      # Create milk subscription
      subscription = MilkSubscription.create!(subscription_params)

      # Create customer format record
      CustomerFormat.create!(
        customer_id: customer.id,
        product_id: product.id,
        delivery_person_id: delivery_person&.id,
        quantity: subscription_params[:quantity],
        pattern: 'every_day', # Default pattern for daily delivery
        status: 'active'
      )

      # Create daily delivery tasks
      create_daily_tasks(subscription, row)

      @imported_count += 1
    end

    def find_product(row, row_number)
      product_id = get_row_value(row, 'product_id')
      product_name = get_row_value(row, 'product_name')

      product = nil
      if product_id.present?
        begin
          product = Product.find(Integer(product_id))
        rescue ArgumentError, ActiveRecord::RecordNotFound
          # Fall through to product_name search
        end
      end

      if product.nil? && product_name.present?
        product = Product.find_by(name: product_name.strip)
      end

      if product.nil?
        raise "Product not found with ID '#{product_id}' or name '#{product_name}'"
      end

      product
    end

    def find_delivery_person(row, row_number)
      delivery_person_id = get_row_value(row, 'delivery_person_id')
      delivery_person_name = get_row_value(row, 'delivery_person_name')

      return nil if delivery_person_id.blank? && delivery_person_name.blank?

      delivery_person = nil
      if delivery_person_id.present?
        begin
          delivery_person = DeliveryPerson.find(Integer(delivery_person_id))
        rescue ArgumentError, ActiveRecord::RecordNotFound
          # Fall through to name search
        end
      end

      if delivery_person.nil? && delivery_person_name.present?
        # Search by first name + last name
        names = delivery_person_name.strip.split(' ')
        if names.length >= 2
          delivery_person = DeliveryPerson.where(first_name: names[0], last_name: names[1..-1].join(' ')).first
        else
          delivery_person = DeliveryPerson.where(first_name: delivery_person_name.strip).first
        end
      end

      delivery_person # Can be nil if not found
    end

    def create_daily_tasks(subscription, row = nil)
      start_date = subscription.start_date
      end_date = subscription.end_date

      # Check if row contains daily quantity columns (1-31 for each day)
      has_daily_quantities = row && (1..31).any? { |day| get_row_value(row, day.to_s).present? }

      if has_daily_quantities
        # Create tasks based on daily quantities in columns 1-31
        (start_date..end_date).each_with_index do |date, index|
          day_column = (index + 1).to_s # Day 1, Day 2, etc.
          daily_quantity = get_row_value(row, day_column)

          # Skip if day exceeds 31 or quantity is 'X' or blank
          next if index >= 31 || daily_quantity.blank? || daily_quantity.upcase == 'X'

          # Skip if task already exists for this date
          next if MilkDeliveryTask.exists?(
            subscription_id: subscription.id,
            customer_id: subscription.customer_id,
            delivery_date: date
          )

          # Parse quantity (could be 0.5, 1, 1.5, etc.)
          quantity = parse_decimal(daily_quantity)
          next if quantity.nil? || quantity <= 0

          MilkDeliveryTask.create!(
            subscription_id: subscription.id,
            customer_id: subscription.customer_id,
            product_id: subscription.product_id,
            delivery_person_id: subscription.delivery_person_id,
            quantity: quantity,
            unit: subscription.unit,
            delivery_date: date,
            status: 'completed', # Set as completed as per requirement
            completed_at: date.beginning_of_day + 8.hours # Mark as completed at 8 AM
          )
        end
      else
        # Default behavior: create tasks with subscription quantity for all days
        (start_date..end_date).each do |date|
          # Skip if task already exists for this date
          next if MilkDeliveryTask.exists?(
            subscription_id: subscription.id,
            customer_id: subscription.customer_id,
            delivery_date: date
          )

          MilkDeliveryTask.create!(
            subscription_id: subscription.id,
            customer_id: subscription.customer_id,
            product_id: subscription.product_id,
            delivery_person_id: subscription.delivery_person_id,
            quantity: subscription.quantity,
            unit: subscription.unit,
            delivery_date: date,
            status: 'pending'
          )
        end
      end
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string.to_s)
    rescue ArgumentError
      nil
    end

    def parse_decimal(decimal_string)
      return nil if decimal_string.blank?
      BigDecimal(decimal_string.to_s)
    rescue ArgumentError
      nil
    end

    def parse_boolean(boolean_string, default: false)
      return default if boolean_string.blank?
      ['true', '1', 'yes', 'on', 'active'].include?(boolean_string.to_s.downcase)
    end

    # Helper method to get row values that handles headers with asterisks
    def get_row_value(row, field_name)
      # Try with asterisk first (for required fields), then without
      row["#{field_name}*"] || row[field_name]
    end

    # Generate a secure password for auto-creation
    def generate_secure_password(customer)
      # Generate password in format: Welcome@123
      # This is the default generic password requested
      "Welcome@123"
    end
  end
end