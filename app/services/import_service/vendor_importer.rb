require 'csv'
require 'roo'

module ImportService
  # Bulk-imports vendors from a CSV / Excel file.
  #
  # Only `name` is required (Vendor model validation). Every other field a vendor
  # has when created through the admin form is accepted but optional:
  #   phone, email, address, gst_no, payment_type (Cash/Credit), opening_balance, status
  #
  # Blank payment_type defaults to "Cash" and blank status defaults to active,
  # so a file containing nothing but a `name` column still imports cleanly.
  class VendorImporter
    attr_reader :file, :imported_count, :skipped_count, :errors

    def initialize(file)
      @file = file
      @imported_count = 0
      @skipped_count = 0
      @errors = []
    end

    def import
      spreadsheet = open_spreadsheet(@file)
      header = spreadsheet.row(1).map { |h| h.to_s.strip }

      validate_headers(header)

      (2..spreadsheet.last_row).each do |i|
        raw = spreadsheet.row(i)
        next if raw.compact.all? { |v| v.to_s.strip.blank? } # skip empty rows

        row = Hash[[header, raw].transpose]
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

    private

    def open_spreadsheet(file)
      case File.extname(file.original_filename).downcase
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
      normalized = header.map { |h| h.to_s.downcase.strip }
      unless normalized.include?('name')
        raise "Missing required header: name"
      end
    end

    def process_row(row, row_number)
      attrs = normalize(row)

      if attrs[:name].blank?
        @errors << "Row #{row_number}: name is required"
        @skipped_count += 1
        return
      end

      if Vendor.where('LOWER(name) = ?', attrs[:name].downcase).exists?
        @errors << "Row #{row_number}: Vendor '#{attrs[:name]}' already exists"
        @skipped_count += 1
        return
      end

      vendor = Vendor.new(attrs)

      if vendor.save
        @imported_count += 1
      else
        @errors << "Row #{row_number}: #{vendor.errors.full_messages.join(', ')}"
        @skipped_count += 1
      end
    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
    end

    def normalize(row)
      {
        name: cell(row, 'name'),
        phone: cell(row, 'phone'),
        email: cell(row, 'email')&.downcase,
        address: cell(row, 'address'),
        gst_no: cell(row, 'gst_no')&.upcase,
        payment_type: normalize_payment_type(cell(row, 'payment_type')),
        opening_balance: parse_decimal(cell(row, 'opening_balance')),
        status: parse_status(cell(row, 'status'))
      }
    end

    # Case-insensitive header lookup so "Name" / "NAME" / "name" all work.
    def cell(row, key)
      pair = row.find { |k, _| k.to_s.downcase.strip == key }
      value = pair&.last
      value.to_s.strip.presence
    end

    def normalize_payment_type(value)
      return 'Cash' if value.blank?

      case value.downcase
      when 'cash' then 'Cash'
      when 'credit' then 'Credit'
      else value
      end
    end

    def parse_status(value)
      return true if value.blank?

      %w[false 0 no inactive n].exclude?(value.downcase)
    end

    def parse_decimal(value)
      return nil if value.blank?
      BigDecimal(value.to_s.gsub(/[^0-9.\-]/, ''))
    rescue ArgumentError
      nil
    end
  end
end
