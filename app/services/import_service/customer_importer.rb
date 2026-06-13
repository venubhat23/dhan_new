require 'csv'
require 'roo'
require 'bcrypt'

module ImportService
  class CustomerImporter
    attr_reader :file, :imported_count, :skipped_count, :errors

    def initialize(file)
      @file = file
      @imported_count = 0
      @skipped_count = 0
      @errors = []
    end

    def import
      begin
        spreadsheet = open_spreadsheet(@file)
        header = spreadsheet.row(1)

        validate_headers(header)

        (2..spreadsheet.last_row).each do |i|
          clean_header = header.map { |h| h.to_s.gsub('*', '').strip }
          row = Hash[[clean_header, spreadsheet.row(i)].transpose]
          process_row(row, i)
        end

        {
          success: true,
          imported_count: @imported_count,
          skipped_count: @skipped_count,
          errors: @errors
        }
      rescue => e
        {
          success: false,
          error: e.message,
          imported_count: @imported_count,
          skipped_count: @skipped_count,
          errors: @errors
        }
      end
    end

    private

    def open_spreadsheet(file)
      case File.extname(file.original_filename)
      when '.csv'
        Roo::CSV.new(file.path)
      when '.xls'
        Roo::Excel.new(file.path)
      when '.xlsx'
        Roo::Excelx.new(file.path)
      else
        raise "Unknown file type: #{file.original_filename}"
      end
    end

    def validate_headers(header)
      clean_headers = header.map(&:to_s).map { |h| h.gsub('*', '').downcase.strip }
      required_headers = %w[customer_name mobile]
      missing_headers = required_headers - clean_headers

      if missing_headers.any?
        raise "Missing required headers: #{missing_headers.join(', ')}"
      end
    end

    def process_row(row, row_number)
      customer_data = normalize_customer_data(row)

      if !valid_row?(customer_data, row_number)
        @skipped_count += 1
        return
      end

      if duplicate_customer?(customer_data)
        msg = "Row #{row_number}: Customer with mobile '#{customer_data[:mobile]}'"
        msg += " or email '#{customer_data[:email]}'" if customer_data[:email].present?
        msg += " already exists"
        @errors << msg
        @skipped_count += 1
        return
      end

      customer = Customer.new(customer_data)

      if customer.save
        @imported_count += 1
      else
        @errors << "Row #{row_number}: #{customer.errors.full_messages.join(', ')}"
        @skipped_count += 1
      end

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
    end

    def normalize_customer_data(row)
      customer_name = row['customer_name']&.to_s&.strip
      password = generate_password(customer_name)

      {
        first_name:       customer_name,
        email:            row['email']&.to_s&.downcase&.strip.presence,
        mobile:           row['mobile']&.to_s&.strip,
        whatsapp_number:  row['whatsapp_number']&.to_s&.strip.presence || row['mobile']&.to_s&.strip,
        gst_no:           row['gst_no']&.to_s&.strip&.upcase,
        address:          row['address']&.to_s&.strip,
        notes:            row['notes']&.to_s&.strip,
        status:           parse_boolean(row['status']),
        password_digest:  BCrypt::Password.create(password),
        auto_generated_password: password
      }.compact
    end

    def valid_row?(customer_data, row_number)
      if customer_data[:first_name].blank?
        @errors << "Row #{row_number}: customer_name is required"
        return false
      end

      if customer_data[:mobile].blank?
        @errors << "Row #{row_number}: mobile is required"
        return false
      end

      if customer_data[:email].present? && !customer_data[:email].match?(URI::MailTo::EMAIL_REGEXP)
        @errors << "Row #{row_number}: Invalid email format"
        return false
      end

      if customer_data[:mobile].present?
        clean_mobile = customer_data[:mobile].gsub(/\D/, '')
        unless clean_mobile.match?(/^\d{7,15}$/)
          @errors << "Row #{row_number}: Invalid mobile number format"
          return false
        end
        customer_data[:mobile] = clean_mobile
      end

      true
    end

    def duplicate_customer?(customer_data)
      return true if Customer.exists?(mobile: customer_data[:mobile])
      return true if customer_data[:email].present? && Customer.exists?(email: customer_data[:email])
      false
    end

    def parse_boolean(value)
      return true if value.blank?

      case value.to_s.downcase.strip
      when 'true', '1', 'yes', 'y', 'active'
        true
      when 'false', '0', 'no', 'n', 'inactive'
        false
      else
        true
      end
    end

    # Password: first 3 chars of first name (capitalized) + @DHAN
    # e.g. "Rahul" → "Rah@DHAN", "Jo" → "Jo@DHAN"
    def generate_password(first_name)
      name_part = first_name.to_s.strip[0, 3].capitalize
      "#{name_part}@DHAN"
    end
  end
end
