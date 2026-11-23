require 'csv'

# Turns a Gstr1Report into the GSTR-1 workbook layout (one table per sheet).
# Each sheet is a list of rows (arrays); the same rows feed the Excel file
# (all sheets) and the per-sheet CSV download.
class Gstr1Export
  SHEETS = %w[gstr1 b2b b2cl b2cs cdnr cdnur exemp hsn(b2b) hsn(b2c) docs].freeze

  NOTE_HEAD = ['GSTIN', 'Customer Name', 'Place of supply', '', 'Invoice Details', '', '', '', 'Total Tax%',
               'Taxable Value', 'Amount of Tax', '', '', '', ''].freeze
  NOTE_SUB = ['', '', 'State Code', 'State Name', 'Invoice Number', 'Invoice Date', 'Invoice value', 'Invoice Type',
              '', '', 'Central Tax Amount', 'State/UT Tax Amount', 'Integrated Tax Amount', 'Cess Amt.',
              'Total Tax Amt.'].freeze
  HSN_HEAD = ['HSN', 'Description', 'UQC', 'Total Quantity', 'Total Value', 'Rate', 'Taxable Value',
              'Integrated Tax Amount', 'Central Tax Amount', 'State/UT Tax Amount', 'Cess Amount'].freeze

  # Row indexes (0-based) of title / header rows per sheet, for bold styling.
  attr_reader :bold_rows

  def initialize(report)
    @r = report
    @bold_rows = Hash.new { |h, k| h[k] = [] }
  end

  def rows_for(sheet)
    case sheet
    when 'gstr1' then gstr1_rows
    when 'b2b' then b2b_rows
    when 'b2cl' then b2cl_rows
    when 'b2cs' then b2cs_rows
    when 'cdnr' then cdnr_rows
    when 'cdnur' then cdnur_rows
    when 'exemp' then exemp_rows
    when 'hsn(b2b)' then hsn_rows(true, sheet)
    when 'hsn(b2c)' then hsn_rows(false, sheet)
    when 'docs' then docs_rows
    else []
    end
  end

  def to_csv(sheet)
    CSV.generate { |csv| rows_for(sheet).each { |row| csv << row } }
  end

  def to_xlsx
    require 'write_xlsx'
    file = Tempfile.new(['gstr1', '.xlsx'])
    file.close
    wb = WriteXLSX.new(file.path)
    bold = wb.add_format(bold: 1)
    head = wb.add_format(bold: 1, bg_color: '#FBD5C9', border: 1)
    money = wb.add_format(num_format: '0.00')
    SHEETS.each do |name|
      ws = wb.add_worksheet(name)
      ws.set_column(0, 0, 22)
      ws.set_column(1, 1, 26)
      ws.set_column(2, 16, 15)
      rows = rows_for(name)
      rows.each_with_index do |row, ri|
        fmt = if @bold_rows[name].include?([:head, ri]) then head
              elsif @bold_rows[name].include?([:bold, ri]) then bold
              end
        row.each_with_index do |v, ci|
          next if v.nil? || v == ''
          if v.is_a?(Numeric)
            ws.write_number(ri, ci, v, fmt || money)
          else
            ws.write_string(ri, ci, v.to_s, fmt)
          end
        end
      end
    end
    wb.close
    File.binread(file.path)
  ensure
    file&.unlink
  end

  private

  def d(date) = date&.strftime('%d/%m/%Y').to_s
  def dmy(date) = date&.strftime('%d-%b-%Y').to_s
  def rate_cell(rate) = rate.positive? ? clean(rate) : ''
  def clean(n) = n.to_f == n.to_i ? n.to_i : n.to_f.round(2)

  def mark(sheet, rows, kind)
    @bold_rows[sheet] << [kind, rows.size - 1]
  end

  def push(sheet, rows, row, kind = nil)
    rows << row
    mark(sheet, rows, kind) if kind
  end

  # ---- gstr1 (summary sheet) ----------------------------------------------

  def gstr1_rows
    s = 'gstr1'
    rows = []
    push(s, rows, [@r.business[:name]], :bold)
    push(s, rows, [@r.business[:phone] ? "Phone No: #{@r.business[:phone]}" : ''])
    push(s, rows, [@r.business[:gstin] ? "GSTIN: #{@r.business[:gstin]}" : ''])
    push(s, rows, [])
    push(s, rows, ['GSTR-1'], :bold)
    push(s, rows, ["Dated: #{d(@r.from_date)}-#{d(@r.to_date)}"])
    push(s, rows, [])
    push(s, rows, ['Sales'], :bold)
    push(s, rows, ['GSTIN', 'Customer Name', 'Place of supply', '', 'Invoice Details', '', '', 'Total Tax%',
                   'Taxable Value', 'Amount of Tax', '', '', '', ''], :head)
    push(s, rows, ['', '', 'State Code', 'State Name', 'Invoice Number', 'Invoice Date', 'Invoice value', '', '',
                   'Central Tax Amount', 'State/UT Tax Amount', 'Integrated Tax Amount', 'Cess Amt.',
                   'Total Tax Amt.'], :head)
    @r.sales.each do |doc|
      slabs = doc.slabs.presence || [Gstr1Report::Slab.new(rate: 0.0, taxable: 0.0, cgst: 0.0, sgst: 0.0, igst: 0.0)]
      slabs.each_with_index do |sl, i|
        head = i.zero? ? [doc.gstin.to_s, doc.name, doc.state_code.to_i, doc.state_name, doc.number, d(doc.date), doc.value]
                       : ['', '', '', '', '', '', '']
        rows << head + [rate_cell(sl.rate), sl.taxable, sl.cgst, sl.sgst, sl.igst, 0, sl.tax]
      end
    end
    t = @r.totals(@r.sales)
    push(s, rows, ['Total', '', '', '', '', '', t[:value], '', t[:taxable], t[:cgst], t[:sgst], t[:igst], 0, t[:tax]], :bold)

    note_section(s, rows, 'Sales Return', @r.sales_returns, 'Credit Note')
    note_section(s, rows, 'Purchase Return', @r.purchase_returns, 'Debit Note')
    rows
  end

  def note_section(s, rows, title, docs, type)
    3.times { rows << [] }
    push(s, rows, [title], :bold)
    push(s, rows, NOTE_HEAD.dup, :head)
    push(s, rows, NOTE_SUB.dup, :head)
    docs.each do |doc|
      doc.slabs.each_with_index do |sl, i|
        head = i.zero? ? [doc.gstin.to_s, doc.name, doc.state_code.to_i, doc.state_name, doc.number, d(doc.date), doc.value, type]
                       : ['', '', '', '', '', '', '', '']
        rows << head + [rate_cell(sl.rate), sl.taxable, sl.cgst, sl.sgst, sl.igst, 0, sl.tax]
      end
    end
    t = @r.totals(docs)
    push(s, rows, ['Total', '', '', '', '', '', t[:value], '', '', t[:taxable], t[:cgst], t[:sgst], t[:igst], 0, t[:tax]], :bold)
  end

  # ---- portal sheets ----------------------------------------------------------

  def b2b_rows
    s = 'b2b'
    docs = @r.b2b_sales.select { |d| d.taxed_slabs.any? }
    rows = []
    push(s, rows, ['Summary For B2B'], :bold)
    push(s, rows, ['No. of Recipients', '', 'No. of Invoices', '', 'Total Invoice Value', '', '', '', '', '', '',
                   'Total Taxable', 'Total Cess'], :head)
    rows << [docs.map(&:gstin).uniq.size, '', docs.size, '', docs.sum(&:value).round(2), '', '', '', '', '', '',
             docs.sum { |d| d.taxed_slabs.sum(&:taxable) }.round(2), 0]
    push(s, rows, ['GSTIN/UIN of Recipient', 'Receiver Name', 'Invoice Number', 'Invoice date', 'Invoice Value',
                   'Place Of Supply', 'Reverse Charge', 'Applicable % of Tax Rate', 'Invoice Type',
                   'E-Commerce GSTIN', 'Rate', 'Taxable Value', 'Cess Amount'], :head)
    docs.each do |doc|
      doc.taxed_slabs.each do |sl|
        rows << [doc.gstin, doc.name, doc.number, dmy(doc.date), doc.value, doc.pos, 'N', '', 'Regular B2B', '',
                 clean(sl.rate), sl.taxable, 0]
      end
    end
    rows
  end

  def b2cl_rows
    s = 'b2cl'
    docs = @r.b2cl_sales.select { |d| d.taxed_slabs.any? }
    rows = []
    push(s, rows, ['Summary For B2CL'], :bold)
    push(s, rows, ['No. of Invoices', '', 'Total Invoice Value', '', '', '', 'Total Taxable Value', 'Total Cess', ''], :head)
    rows << [docs.size, '', docs.sum(&:value).round(2), '', '', '', docs.sum { |d| d.taxed_slabs.sum(&:taxable) }.round(2), 0, '']
    push(s, rows, ['Invoice Number', 'Invoice date', 'Invoice Value', 'Place Of Supply', 'Applicable % of Tax Rate',
                   'Rate', 'Taxable Value', 'Cess Amount', 'E-Commerce GSTIN'], :head)
    docs.each do |doc|
      doc.taxed_slabs.each { |sl| rows << [doc.number, dmy(doc.date), doc.value, doc.pos, '', clean(sl.rate), sl.taxable, 0, ''] }
    end
    rows
  end

  def b2cs_rows
    s = 'b2cs'
    data = @r.b2cs_rows
    rows = []
    push(s, rows, ['Summary For B2CS'], :bold)
    push(s, rows, ['', '', '', '', 'Total Taxable Value', 'Total Cess', ''], :head)
    rows << ['', '', '', '', data.sum { |x| x[:taxable] }.round(2), 0, '']
    push(s, rows, ['Type', 'Place Of Supply', 'Applicable % of Tax Rate', 'Rate', 'Taxable Value', 'Cess Amount',
                   'E-Commerce GSTIN'], :head)
    data.each { |x| rows << [x[:type], x[:pos], '', clean(x[:rate]), x[:taxable], 0, ''] }
    rows
  end

  def cdnr_rows
    s = 'cdnr'
    docs = @r.cdnr
    rows = []
    push(s, rows, ['Summary For CDNR'], :bold)
    push(s, rows, ['No. of Recipients', 'No. of Notes', '', '', '', '', '', 'Total Note Value', '', '',
                   'Total Taxable Value', 'Total Cess', ''], :head)
    rows << [docs.map(&:gstin).uniq.size, docs.size, '', '', '', '', '', docs.sum(&:value).round(2), '', '',
             docs.sum(&:taxable).round(2), 0, '']
    push(s, rows, ['GSTIN/UIN of Recipient', 'Receiver Name', 'Note Number', 'Note Date', 'Note Type',
                   'Place Of Supply', 'Reverse Charge', 'Note Supply Type', 'Note Value',
                   'Applicable % of Tax Rate', 'Rate', 'Taxable Value', 'Cess Amount'], :head)
    docs.each do |doc|
      doc.slabs.each do |sl|
        rows << [doc.gstin, doc.name, doc.number, dmy(doc.date), 'C', doc.pos, 'N', 'Regular B2B', doc.value, '',
                 clean(sl.rate), sl.taxable, 0]
      end
    end
    rows
  end

  def cdnur_rows
    s = 'cdnur'
    docs = @r.cdnur
    rows = []
    push(s, rows, ['Summary For CDNUR'], :bold)
    push(s, rows, ['', 'No. of Notes/Vouchers', '', '', '', 'Total Note Value', '', '', 'Total Taxable Value',
                   'Total Cess'], :head)
    rows << ['', docs.size, '', '', '', docs.sum(&:value).round(2), '', '', docs.sum(&:taxable).round(2), 0]
    push(s, rows, ['UR Type', 'Note Number', 'Note Date', 'Note Type', 'Place Of Supply', 'Note Value',
                   'Applicable % of Tax Rate', 'Rate', 'Taxable Value', 'Cess Amount'], :head)
    docs.each do |doc|
      doc.slabs.each { |sl| rows << ['B2CL', doc.number, dmy(doc.date), 'C', doc.pos, doc.value, '', clean(sl.rate), sl.taxable, 0] }
    end
    rows
  end

  def exemp_rows
    s = 'exemp'
    data = @r.exempt_rows
    rows = []
    push(s, rows, ['Summary For Nil rated, exempted and non GST outward supplies (8)'], :bold)
    push(s, rows, ['', 'Total Nil Rated Supplies', 'Total Exempted Supplies', 'Total Non-GST Supplies'], :head)
    rows << ['', data.sum { |x| x[:nil_rated] }.round(2), 0.0, data.sum { |x| x[:non_gst] }.round(2)]
    push(s, rows, ['Description', 'Nil Rated Supplies', 'Exempted(other than nil rated/non GST supply)',
                   'Non-GST Supplies'], :head)
    data.each { |x| rows << [x[:description], x[:nil_rated], x[:exempted], x[:non_gst]] }
    rows
  end

  def hsn_rows(registered, s)
    data = @r.hsn_rows(registered)
    rows = []
    push(s, rows, ["Summary For HSN(12)"], :bold)
    push(s, rows, ['No. of HSN', '', '', '', 'Total Value', '', 'Total Taxable Value', 'Total Integrated Tax',
                   'Total Central Tax', 'Total State/UT Tax', 'Total Cess'], :head)
    rows << [data.map { |x| x[:hsn] }.uniq.size, '', '', '', data.sum { |x| x[:value] }.round(2), '',
             data.sum { |x| x[:taxable] }.round(2), data.sum { |x| x[:igst] }.round(2),
             data.sum { |x| x[:cgst] }.round(2), data.sum { |x| x[:sgst] }.round(2), 0]
    push(s, rows, HSN_HEAD.dup, :head)
    data.each do |x|
      rows << [x[:hsn], x[:description], x[:uqc], clean(x[:quantity]), x[:value], clean(x[:rate]), x[:taxable],
               x[:igst], x[:cgst], x[:sgst], 0]
    end
    rows
  end

  def docs_rows
    s = 'docs'
    data = @r.docs_rows
    rows = []
    push(s, rows, ['Summary of documents issued during the tax period (13)'], :bold)
    push(s, rows, ['', '', '', 'Total Number', 'Total Cancelled'], :head)
    rows << ['', '', '', data.sum { |x| x[:total] }, data.sum { |x| x[:cancelled] }]
    push(s, rows, ['Nature of Document', 'Sr. No. From', 'Sr. No. To', 'Total Number', 'Cancelled'], :head)
    data.each { |x| rows << [x[:nature], x[:from], x[:to], x[:total], x[:cancelled]] }
    rows
  end
end
