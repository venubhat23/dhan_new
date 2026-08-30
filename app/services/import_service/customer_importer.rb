require 'csv'
require 'roo'
require 'bcrypt'

module ImportService
  class CustomerImporter
    attr_reader :file, :imported_count, :skipped_count, :errors

    # Customer fields the "custom column mapping" UI is allowed to target.
    # Maps to the CSV header name used when no explicit mapping is supplied
    # (i.e. the standard template).
    DEFAULT_FIELD_HEADERS = {
      'full_name'        => 'customer_name',
      'email'            => 'email',
      'mobile'           => 'mobile',
      'whatsapp_number'  => 'whatsapp_number',
      'gst_no'           => 'gst_no',
      'address'          => 'address',
      'landmark'         => 'landmark',
      'shipping_address' => 'shipping_address',
      'location_link'    => 'location_link',
      'latitude'         => 'latitude',
      'longitude'        => 'longitude',
      'status'           => 'status'
    }.freeze

    # column_mapping: optional hash of { csv_header => target_customer_field },
    # e.g. { "Name" => "full_name", "Phone" => "mobile" }. When supplied, the
    # importer reads each row by the mapped CSV header instead of expecting
    # the standard template's fixed header names.
    def initialize(file, column_mapping: nil)
      @file = file
      @imported_count = 0
      @skipped_count = 0
      @errors = []
      @field_headers = build_field_headers(column_mapping)
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

    # Builds { target_field => csv_header }. With no mapping given, falls
    # back to the standard template's fixed header names.
    def build_field_headers(column_mapping)
      return DEFAULT_FIELD_HEADERS if column_mapping.blank?

      mapping = {}
      column_mapping.each do |csv_header, target_field|
        next if target_field.blank?
        mapping[target_field.to_s] = csv_header.to_s
      end
      mapping
    end

    def custom_mapping?
      @field_headers != DEFAULT_FIELD_HEADERS
    end

    # Reads a Customer field's value out of a parsed CSV/XLSX row, following
    # whichever header it's mapped to (custom mapping, or the default template).
    def mapped(row, field)
      header = @field_headers[field.to_s]
      header ? row[header] : nil
    end

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
      if custom_mapping?
        missing = %w[full_name mobile] - @field_headers.keys
        raise "Please map a column to: #{missing.join(', ')}" if missing.any?
        return
      end

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
      customer_name = mapped(row, 'full_name')&.to_s&.strip
      mobile        = mapped(row, 'mobile')&.to_s&.strip
      password      = generate_password(customer_name)

      {
        full_name:        customer_name,
        email:            mapped(row, 'email')&.to_s&.downcase&.strip.presence,
        mobile:           mobile,
        whatsapp_number:  mapped(row, 'whatsapp_number')&.to_s&.strip.presence || mobile,
        gst_no:           mapped(row, 'gst_no')&.to_s&.strip&.upcase,
        address:          mapped(row, 'address')&.to_s&.strip,
        landmark:         mapped(row, 'landmark')&.to_s&.strip,
        shipping_address: mapped(row, 'shipping_address')&.to_s&.strip,
        location_link:    mapped(row, 'location_link')&.to_s&.strip,
        latitude:         mapped(row, 'latitude')&.to_s&.strip.presence,
        longitude:        mapped(row, 'longitude')&.to_s&.strip.presence,
        status:           parse_boolean(mapped(row, 'status')),
        password_digest:  BCrypt::Password.create(password),
        auto_generated_password: password
      }.compact
    end

    def valid_row?(customer_data, row_number)
      if customer_data[:full_name].blank?
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

      if customer_data[:latitude].present? && !valid_decimal?(customer_data[:latitude])
        @errors << "Row #{row_number}: Invalid latitude format"
        return false
      end

      if customer_data[:longitude].present? && !valid_decimal?(customer_data[:longitude])
        @errors << "Row #{row_number}: Invalid longitude format"
        return false
      end

      true
    end

    def valid_decimal?(value)
      value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
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
