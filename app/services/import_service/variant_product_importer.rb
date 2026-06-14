require 'csv'
require 'roo'

module ImportService
  class VariantProductImporter
    MAX_VARIANTS = 5

    attr_reader :file, :imported_count, :skipped_count, :errors

    def initialize(file)
      @file = file
      @imported_count = 0
      @skipped_count = 0
      @errors = []
    end

    def import
      spreadsheet = open_spreadsheet(@file)
      header = spreadsheet.row(1).map { |h| h.to_s.gsub('*', '').strip.downcase }

      validate_headers(header)

      (2..spreadsheet.last_row).each do |i|
        row = Hash[header.zip(spreadsheet.row(i))]
        process_row(row, i)
      end

      { success: true, imported_count: @imported_count, skipped_count: @skipped_count, errors: @errors }
    rescue => e
      { success: false, error: e.message, imported_count: @imported_count, skipped_count: @skipped_count, errors: @errors }
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
      required = %w[name category weight1 unit1 selling_price1 cost_price1 stock1]
      missing = required - headers
      raise "Missing required headers: #{missing.join(', ')}" if missing.any?
    end

    def process_row(row, row_number)
      name = row['name'].to_s.strip
      if name.blank?
        @errors << "Row #{row_number}: name is required"
        @skipped_count += 1
        return
      end

      category = find_or_create_category(row['category'].to_s.strip)
      unless category
        @errors << "Row #{row_number}: category '#{row['category']}' could not be found or created"
        @skipped_count += 1
        return
      end

      # product_type is optional — default to 'Grocery' if blank or invalid
      product_type = row['product_type'].to_s.strip
      product_type = 'Grocery' unless Product::PRODUCT_TYPES.map(&:last).include?(product_type)

      # Build variants from numbered columns
      variants_attrs = []
      (1..MAX_VARIANTS).each do |n|
        weight          = row["weight#{n}"].to_s.strip
        unit            = row["unit#{n}"].to_s.strip
        sp              = row["selling_price#{n}"].to_s.strip
        cp              = row["cost_price#{n}"].to_s.strip
        pp              = row["purchase_price#{n}"].to_s.strip
        stock           = row["stock#{n}"].to_s.strip
        b2b_price       = row["b2b_price#{n}"].to_s.strip
        b2b_pct         = row["b2b_percentage#{n}"].to_s.strip
        low_thresh      = row["low_threshold#{n}"].to_s.strip

        break if weight.blank? && sp.blank?
        next if weight.blank? || sp.blank?

        variants_attrs << {
          weight:              weight.to_f,
          unit:                unit.presence || 'Liter',
          selling_price:       sp.to_f,
          buying_price:        cp.presence ? cp.to_f : sp.to_f,
          purchase_price:      pp.presence ? pp.to_f : nil,
          b2b_price:           b2b_price.presence ? b2b_price.to_f : nil,
          b2b_percentage:      b2b_pct.presence ? b2b_pct.to_f : nil,
          low_stock_threshold: low_thresh.presence ? low_thresh.to_i : 10,
          available_stock:     stock.to_i,
          is_default:          n == 1
        }
      end

      if variants_attrs.empty?
        @errors << "Row #{row_number}: at least one variant (weight1, unit1, selling_price1, cost_price1, stock1) is required"
        @skipped_count += 1
        return
      end

      product = Product.new(
        name:                    name,
        category:                category,
        product_type:            product_type,
        status:                  parse_status(row['status']),
        description:             row['description'].to_s.strip,
        is_subscription_enabled: parse_bool(row['is_subscription_enabled']),
        has_multiple_quantities: true,
        unit_type:               variants_attrs.first[:unit],
        is_discounted:           parse_bool(row['is_discounted']),
        discount_type:           row['discount_type'].to_s.strip.presence,
        discount_value:          row['discount_value'].to_s.strip.presence,
        gst_enabled:             parse_bool(row['gst_enabled']),
        gst_percentage:          row['gst_percentage'].to_s.strip.presence,
        hsn_code:                row['hsn_code'].to_s.strip,
        is_occasional_product:   parse_bool(row['is_occasional_product'])
      )

      variants_attrs.each do |va|
        product.product_variants.build(va)
      end

      if product.save
        @imported_count += 1
      else
        @errors << "Row #{row_number}: #{product.errors.full_messages.join(', ')}"
        @skipped_count += 1
      end
    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
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
