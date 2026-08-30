module ImportService
  class CustomerDailyTaskImporter
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
        validator = CsvValidator.new(@uploaded_file, 'customer_daily_tasks')
        validation_result = validator.validate

        unless validation_result[:success]
          return { success: false, error: validation_result[:error] }
        end

        Customer.transaction do
          csv_data.each_with_index do |row, index|
            begin
              process_customer_daily_task_row(row, index + 2)
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
        Rails.logger.error "Customer daily task import error: #{e.message}"
        { success: false, error: e.message }
      end
    end

    private

    def process_customer_daily_task_row(row, row_number)
      # Validate required fields
      customer_name = get_row_value(row, 'Customer Name')
      customer_number = get_row_value(row, 'Customer Number')

      if customer_name.blank? || customer_number.blank?
        raise "Missing required fields: Customer Name and Customer Number are required"
      end

      # Find or create customer (skip email field entirely)
      customer = Customer.find_by(mobile: customer_number.strip)

      if customer.nil?
        customer = Customer.create!(
          full_name: customer_name.strip,
          mobile: customer_number.strip,
          status: true
        )
      end

      # Get other CSV values
      delivery_person_id = get_row_value(row, 'delivery_person_id')
      product_id = get_row_value(row, 'product_id')
      quantity = parse_decimal(get_row_value(row, 'quantity'))
      unit = get_row_value(row, 'unit')
      start_date = parse_date(get_row_value(row, 'start_date'))
      end_date = parse_date(get_row_value(row, 'end_date'))
      pattern = get_row_value(row, 'pattern')

      # Validate required fields
      raise "Missing delivery_person_id" if delivery_person_id.blank?
      raise "Missing product_id" if product_id.blank?
      raise "Missing quantity" if quantity.nil? || quantity <= 0
      raise "Missing unit" if unit.blank?
      raise "Missing start_date" if start_date.nil?
      raise "Missing end_date" if end_date.nil?

      # Validate dates
      raise "start_date must be before end_date" if start_date >= end_date

      # Validate delivery person exists
      delivery_person = DeliveryPerson.find_by(id: delivery_person_id)
      raise "Delivery person with ID #{delivery_person_id} not found" if delivery_person.nil?

      # Validate product exists and get rate from product
      product = Product.find_by(id: product_id)
      raise "Product with ID #{product_id} not found" if product.nil?

      # Get rate from product (use final_amount_with_gst if GST enabled, else selling_price)
      if product.gst_enabled? && product.final_amount_with_gst.present?
        rate = product.final_amount_with_gst
      else
        rate = product.selling_price || product.price || 0
      end
      raise "Product #{product.name} has no valid price set" if rate <= 0

      # Calculate total amount
      days_count = (end_date - start_date).to_i + 1
      total_amount = quantity * rate * days_count

      # Create milk subscription
      subscription = MilkSubscription.create!(
        customer_id: customer.id,
        product_id: product_id.to_i,
        delivery_person_id: delivery_person_id.to_i,
        quantity: quantity,
        unit: unit,
        start_date: start_date,
        end_date: end_date,
        delivery_time: '08:00',
        is_active: true,
        status: 'active',
        total_amount: total_amount
      )

      # Create customer format record
      customer_format = CustomerFormat.create!(
        customer_id: customer.id,
        product_id: product_id.to_i,
        delivery_person_id: delivery_person_id.to_i,
        quantity: quantity,
        pattern: pattern == 'everyday' ? 'every_day' : (pattern || 'every_day'),
        status: 'active'
      )

      # Update all delivery tasks to completed status (since subscription model creates them as pending)
      MilkDeliveryTask.where(subscription_id: subscription.id).update_all(
        status: 'completed',
        completed_at: Date.current.beginning_of_day + 8.hours
      )

      @imported_count += 1
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

    # Helper method to get row values that handles headers with asterisks
    def get_row_value(row, field_name)
      # Try with asterisk first (for required fields), then without
      row["#{field_name}*"] || row[field_name]
    end
  end
end