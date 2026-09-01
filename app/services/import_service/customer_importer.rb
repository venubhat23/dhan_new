require 'csv'
require 'roo'
require 'bcrypt'

module ImportService
  class CustomerImporter
    attr_reader :file, :imported_count, :skipped_count, :errors, :failed_rows

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
    #
    # create_users: when true (the default, driven by the "Create user accounts
    # automatically" checkbox), each imported customer that has an email also
    # gets a linked User record (user_type: 'customer') so they can log in.
    def initialize(file, column_mapping: nil, create_users: true)
      @file = file
      @create_users = create_users
      @imported_count = 0
      @skipped_count = 0
      @users_created = 0
      @errors = []
      @notes = []
      @failed_rows = []
      @field_headers = build_field_headers(column_mapping)
    end

    def import
      begin
        spreadsheet = open_spreadsheet(@file)
        header = spreadsheet.row(1)

        validate_headers(header)

        clean_header = header.map { |h| normalize_header(h) }
        (2..spreadsheet.last_row).each do |i|
          row = Hash[[clean_header, spreadsheet.row(i)].transpose]
          process_row(row, i)
        end

        {
          success: true,
          imported_count: @imported_count,
          skipped_count: @skipped_count,
          users_created: @users_created,
          errors: @errors,
          notes: @notes,
          failed_rows: @failed_rows
        }
      rescue => e
        {
          success: false,
          error: e.message,
          imported_count: @imported_count,
          skipped_count: @skipped_count,
          users_created: @users_created,
          errors: @errors,
          notes: @notes,
          failed_rows: @failed_rows
        }
      end
    end

    private

    # Builds { target_field => csv_header }. With no mapping given, falls
    # back to the standard template's fixed header names.
    #
    # csv_header is normalised the same way the row hash keys are (asterisks
    # stripped, trimmed) so a mapping built from a "customer_name*" column
    # still resolves against the "customer_name" row key.
    def build_field_headers(column_mapping)
      return DEFAULT_FIELD_HEADERS if column_mapping.blank?

      mapping = {}
      column_mapping.each do |csv_header, target_field|
        next if target_field.blank?
        mapping[target_field.to_s] = normalize_header(csv_header)
      end
      mapping
    end

    # Strips the "*" required-field marker and surrounding whitespace so header
    # text from the template ("customer_name*") matches the mapping keys.
    def normalize_header(value)
      value.to_s.gsub('*', '').strip
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
      display_name  = customer_data[:full_name].presence || '(blank)'

      reason = validation_error(customer_data)
      if reason
        record_failure(row_number, display_name, reason)
        return
      end

      if duplicate_customer?(customer_data)
        reason = "Customer with mobile '#{customer_data[:mobile]}'"
        reason += " or email '#{customer_data[:email]}'" if customer_data[:email].present?
        reason += " already exists"
        record_failure(row_number, display_name, reason)
        return
      end

      customer = Customer.new(customer_data)

      if customer.save
        @imported_count += 1
        create_user_account(customer, row_number) if @create_users
      else
        record_failure(row_number, display_name, customer.errors.full_messages.join(', '))
      end

    rescue => e
      record_failure(row_number, customer_data&.dig(:full_name).presence || '(unknown)', e.message)
    end

    # Mirrors the admin "create customer" flow: every imported customer gets a
    # linked User (user_type: 'customer') so they can log in. Customers with a
    # real email log in with it; those without one get a non-deliverable
    # placeholder email (User requires a unique email) and log in with their
    # mobile number. Failure here never rolls back the imported customer &mdash;
    # it's recorded as a note.
    def create_user_account(customer, row_number)
      login_email = customer.email.presence || customer.placeholder_email
      return if login_email.blank?
      return if User.exists?(email: login_email)
      return if customer.mobile.present? && User.exists?(mobile: customer.mobile)

      names = customer.full_name.to_s.split(' ')

      User.create!(
        first_name:            names.first.presence || 'Unknown',
        last_name:             (names[1..-1] || []).join(' ').presence || 'Unknown',
        email:                 login_email,
        mobile:                customer.mobile,
        password:              DEFAULT_CUSTOMER_PASSWORD,
        password_confirmation: DEFAULT_CUSTOMER_PASSWORD,
        user_type:             'customer',
        address:               customer.address,
        city:                  'Unknown',
        state:                 'Unknown',
        pincode:               '000000',
        country:               'India',
        status:                true,
        is_active:             true,
        is_verified:           false
      )
      @users_created += 1
    rescue => e
      Rails.logger.warn "CustomerImporter: could not create user account for #{customer.full_name} (#{customer.email.presence || customer.mobile}): #{e.message}"
      @notes << "Row #{row_number}: '#{customer.full_name}' was imported, but a login account could not be created (#{e.message}). Use \"Create User & Set Password\" on the customer's page."
    end

    def record_failure(row_number, name, error_message)
      @errors << "Row #{row_number}: #{error_message}"
      @failed_rows << { row: row_number, name: name, error: error_message }
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

    # Returns a human-readable reason string when the row is invalid, or nil
    # when it passes validation. Also normalises the mobile number in place.
    def validation_error(customer_data)
      return "customer_name is required" if customer_data[:full_name].blank?
      return "mobile is required" if customer_data[:mobile].blank?

      if customer_data[:email].present? && !customer_data[:email].match?(URI::MailTo::EMAIL_REGEXP)
        return "Invalid email format ('#{customer_data[:email]}')"
      end

      if customer_data[:mobile].present?
        clean_mobile = customer_data[:mobile].gsub(/\D/, '')
        return "Invalid mobile number format ('#{customer_data[:mobile]}')" unless clean_mobile.match?(/^\d{7,15}$/)
        customer_data[:mobile] = clean_mobile
      end

      if customer_data[:latitude].present? && !valid_decimal?(customer_data[:latitude])
        return "Invalid latitude format ('#{customer_data[:latitude]}')"
      end

      if customer_data[:longitude].present? && !valid_decimal?(customer_data[:longitude])
        return "Invalid longitude format ('#{customer_data[:longitude]}')"
      end

      nil
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

    # Every imported customer gets the same default login password, matching the
    # admin "create customer" flow (Admin::CustomersController::DEFAULT_CUSTOMER_PASSWORD).
    # It is stored in auto_generated_password so the admin UI can display/copy it.
    DEFAULT_CUSTOMER_PASSWORD = "dhanvantari@123"

    def generate_password(_first_name = nil)
      DEFAULT_CUSTOMER_PASSWORD
    end
  end
end
