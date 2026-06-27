require 'csv'
require 'roo'

module ImportService
  class SimpleProductImporter
    attr_reader :file, :imported_count, :skipped_count, :errors, :failed_rows

    def initialize(file)
      @file = file
      @imported_count = 0
      @skipped_count = 0
      @errors = []
      @failed_rows = []
    end

    def import
      spreadsheet = open_spreadsheet(@file)
      header = spreadsheet.row(1).map { |h| h.to_s.gsub('*', '').strip.downcase }

      validate_headers(header)

      (2..spreadsheet.last_row).each do |i|
        row = Hash[header.zip(spreadsheet.row(i))]
        process_row(row, i)
      end

      { success: true, imported_count: @imported_count, skipped_count: @skipped_count, errors: @errors, failed_rows: @failed_rows }
    rescue => e
      { success: false, error: e.message, imported_count: @imported_count, skipped_count: @skipped_count, errors: @errors, failed_rows: @failed_rows }
    end

    private

    def open_spreadsheet(file)
      case File.extname(file.original_filename)
      when '.csv'  then Roo::CSV.new(file.path)
      when '.xls'  then Roo::Excel.new(file.path)
      when '.xlsx' then Roo::Excelx.new(file.path)
      else raise "Unknown file type: #{file.original_filename}"
      end
    end

    def validate_headers(headers)
      required = %w[name category cost_price selling_price stock unit_type]
      missing = required - headers
      raise "Missing required headers: #{missing.join(', ')}" if missing.any?
    end

    def process_row(row, row_number)
      name = row['name'].to_s.strip
      if name.blank?
        record_failure(row_number, '(blank)', 'Name is required')
        return
      end

      category = find_or_create_category(row['category'].to_s.strip)
      unless category
        record_failure(row_number, name, "Category '#{row['category']}' could not be found or created")
        return
      end

      unit_type = row['unit_type'].to_s.strip
      unless Product::UNIT_TYPES.map(&:last).include?(unit_type)
        record_failure(row_number, name, "Invalid unit_type '#{unit_type}'. Must be one of: #{Product::UNIT_TYPES.map(&:last).join(', ')}")
        return
      end

      low_stock_threshold = row['low_stock_threshold'].to_s.strip.presence
      b2b_price           = row['b2b_price'].to_s.strip.presence
      b2b_percentage      = row['b2b_percentage'].to_s.strip.presence

      product = Product.new(
        name:                    name,
        category:                category,
        status:                  parse_status(row['status']),
        description:             row['description'].to_s.strip,
        is_subscription_enabled: parse_bool(row['is_subscription_enabled']),
        buying_price:            row['cost_price'].to_s.strip.presence,
        purchase_price:          row['purchase_price'].to_s.strip.presence,
        price:                   row['selling_price'].to_s.strip.presence,
        stock:                   row['stock'].to_s.strip.to_i,
        unit_type:               unit_type,
        weight:                  row['weight'].to_s.strip.presence,
        dimensions:              row['dimensions'].to_s.strip,
        is_discounted:           parse_bool(row['is_discounted']),
        discount_type:           row['discount_type'].to_s.strip.presence,
        discount_value:          row['discount_value'].to_s.strip.presence,
        gst_enabled:             parse_bool(row['gst_enabled']),
        gst_percentage:          row['gst_percentage'].to_s.strip.presence,
        hsn_code:                row['hsn_code'].to_s.strip,
        is_occasional_product:   parse_bool(row['is_occasional_product']),
        low_stock_threshold:     low_stock_threshold ? low_stock_threshold.to_i : 10,
        b2b_price:               b2b_price,
        b2b_percentage:          b2b_percentage,
        has_multiple_quantities: false
      )

      if product.save
        @imported_count += 1
      else
        record_failure(row_number, name, product.errors.full_messages.join(', '))
      end
    rescue => e
      record_failure(row_number, row['name'].to_s.strip.presence || '(unknown)', e.message)
    end

    def record_failure(row_number, name, error_message)
      @errors << "Row #{row_number}: #{error_message}"
      @failed_rows << { row: row_number, name: name, error: error_message }
      @skipped_count += 1
    end

    def find_or_create_category(name)
      return nil if name.blank?
      Category.find_or_create_by(name: name) { |c| c.status = true }
    end

    def parse_status(val)
      case val.to_s.downcase.strip
      when 'inactive', 'false', '0' then 'inactive'
      when 'draft' then 'draft'
      else 'active'
      end
    end

    def parse_bool(val)
      %w[true 1 yes y].include?(val.to_s.downcase.strip)
    end
  end
end
