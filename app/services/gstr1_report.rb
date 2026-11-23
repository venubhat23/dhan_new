# GSTR-1 return data for a period, laid out like the accountant's GSTR-1
# workbook (sheets gstr1, b2b, b2cl, b2cs, cdnr, cdnur, exemp, hsn(b2b),
# hsn(b2c), docs).
#
# Source of truth is the Invoice: invoice_items.unit_price is the pre-tax
# (base) price and tax is added on top at the product's GST rate — the same
# arithmetic as admin/invoices/show. Delivery charge is reported as a non-GST
# supply; credit notes (customer returns) are the "Sales Return" section and
# cdnr/cdnur; debit notes (returns to vendor) are the "Purchase Return" section.
class Gstr1Report
  STATES = {
    '01' => 'Jammu and Kashmir', '02' => 'Himachal Pradesh', '03' => 'Punjab', '04' => 'Chandigarh',
    '05' => 'Uttarakhand', '06' => 'Haryana', '07' => 'Delhi', '08' => 'Rajasthan', '09' => 'Uttar Pradesh',
    '10' => 'Bihar', '11' => 'Sikkim', '12' => 'Arunachal Pradesh', '13' => 'Nagaland', '14' => 'Manipur',
    '15' => 'Mizoram', '16' => 'Tripura', '17' => 'Meghalaya', '18' => 'Assam', '19' => 'West Bengal',
    '20' => 'Jharkhand', '21' => 'Odisha', '22' => 'Chhattisgarh', '23' => 'Madhya Pradesh', '24' => 'Gujarat',
    '26' => 'Dadra and Nagar Haveli and Daman and Diu', '27' => 'Maharashtra', '29' => 'Karnataka', '30' => 'Goa',
    '31' => 'Lakshadweep', '32' => 'Kerala', '33' => 'Tamil Nadu', '34' => 'Puducherry',
    '35' => 'Andaman and Nicobar Islands', '36' => 'Telangana', '37' => 'Andhra Pradesh', '38' => 'Ladakh',
    '97' => 'Other Territory'
  }.freeze

  GSTIN_FORMAT = /\A\d{2}[A-Z0-9]{13}\z/
  B2CL_LIMIT = 100_000 # inter-state B2C invoices above this go to B2CL

  UQC = {
    'kg' => 'KGS-KILOGRAMS', 'kgs' => 'KGS-KILOGRAMS', 'gram' => 'GMS-GRAMMES', 'g' => 'GMS-GRAMMES',
    'liter' => 'LTR-LITRES', 'litre' => 'LTR-LITRES', 'l' => 'LTR-LITRES', 'ml' => 'MLT-MILLILITRE',
    'bottle' => 'BTL-BOTTLES', 'pack' => 'PAC-PACKS', 'packet' => 'PAC-PACKS', 'box' => 'BOX-BOX',
    'piece' => 'PCS-PIECES', 'pcs' => 'PCS-PIECES', 'nos' => 'NOS-NUMBERS'
  }.freeze

  CANCELLED_BOOKING_STATUSES = %w[cancelled].freeze

  # One rate slab of one document (invoice / note).
  Slab = Struct.new(:rate, :taxable, :cgst, :sgst, :igst, keyword_init: true) do
    def tax = (cgst + sgst + igst).round(2)
  end

  # An invoice or note with its rate slabs.
  Doc = Struct.new(:number, :date, :gstin, :name, :state_code, :value, :slabs, :record, :kind,
                   keyword_init: true) do
    def registered? = gstin.present?
    def state_name = Gstr1Report::STATES[state_code] || state_code
    def pos = "#{state_code}-#{state_name}"
    def taxed_slabs = slabs.select { |s| s.rate.positive? }
    def taxable = slabs.sum(&:taxable).round(2)
    def cgst = slabs.sum(&:cgst).round(2)
    def sgst = slabs.sum(&:sgst).round(2)
    def igst = slabs.sum(&:igst).round(2)
    def tax = (cgst + sgst + igst).round(2)
  end

  attr_reader :from_date, :to_date

  def initialize(from_date:, to_date:)
    @from_date = from_date
    @to_date = to_date
  end

  # ---- business ---------------------------------------------------------

  def business
    @business ||= begin
      s = SystemSetting.business_settings
      gstin = s.try(:gstin).to_s.strip.upcase
      {
        name: s.try(:business_name).presence || 'Dhanvantari Naturals',
        phone: s.try(:mobile).presence,
        gstin: gstin.presence,
        state_code: gstin =~ /\A\d{2}/ ? gstin[0, 2] : '29'
      }
    end
  end

  def home_state = business[:state_code]

  # ---- invoices ----------------------------------------------------------

  def all_invoices
    @all_invoices ||= Invoice.where(invoice_date: from_date..to_date, payout_type: nil)
                             .where.not(status: 'draft')
                             .includes(:customer, invoice_items: [:product, :product_variant])
                             .to_a.sort_by { |i| [i.invoice_date, natural_key(i.invoice_number)] }
  end

  def bookings_by_number
    @bookings_by_number ||= Booking.where(invoice_number: all_invoices.map(&:invoice_number))
                                   .index_by(&:invoice_number)
  end

  def cancelled?(invoice)
    invoice.cancelled? || CANCELLED_BOOKING_STATUSES.include?(bookings_by_number[invoice.invoice_number]&.status.to_s)
  end

  def cancelled_invoices = all_invoices.select { |i| cancelled?(i) }

  def sales
    @sales ||= all_invoices.reject { |i| cancelled?(i) }.map { |i| build_invoice_doc(i) }
  end

  def b2b_sales = sales.select(&:registered?)
  def b2c_sales = sales.reject(&:registered?)
  def b2cl_sales = b2c_sales.select { |d| d.state_code != home_state && d.value > B2CL_LIMIT }
  def b2cs_sales = b2c_sales - b2cl_sales

  # ---- notes -------------------------------------------------------------

  def sales_returns
    @sales_returns ||= CreditNote.where(credit_date: from_date..to_date)
                                 .includes(:customer, :booking, credit_note_items: :product)
                                 .order(:credit_date, :id).map { |cn| build_credit_doc(cn) }
  end

  def purchase_returns
    @purchase_returns ||= DebitNote.where(debit_date: from_date..to_date)
                                   .includes(:vendor, debit_note_items: :product)
                                   .order(:debit_date, :id).map { |dn| build_debit_doc(dn) }
  end

  def cdnr = sales_returns.select(&:registered?)

  # Unregistered notes are reported only when the original sale was B2CL
  # (inter-state above the limit); the rest are netted inside B2CS.
  def cdnur
    sales_returns.reject(&:registered?).select { |d| d.state_code != home_state && d.record.booking&.total_amount.to_f > B2CL_LIMIT }
  end

  # ---- summaries -----------------------------------------------------------

  def totals(docs)
    {
      value: docs.sum(&:value).round(2), taxable: docs.sum(&:taxable).round(2),
      cgst: docs.sum(&:cgst).round(2), sgst: docs.sum(&:sgst).round(2),
      igst: docs.sum(&:igst).round(2), tax: docs.sum(&:tax).round(2)
    }
  end

  def b2cs_rows
    rows = Hash.new { |h, k| h[k] = 0.0 }
    b2cs_sales.each { |d| d.taxed_slabs.each { |s| rows[[d.pos, s.rate]] += s.taxable } }
    rows.map { |(pos, rate), taxable| { type: 'OE', pos: pos, rate: rate, taxable: taxable.round(2) } }
        .sort_by { |r| [r[:pos], r[:rate]] }
  end

  # Nil-rated (0% lines) and non-GST (delivery charge) supplies, by
  # registered/unregistered and intra/inter state.
  def exempt_rows
    keys = [
      ['Inter-State supplies to registered persons', true, true],
      ['Intra-State supplies to registered persons', true, false],
      ['Inter-State supplies to unregistered persons', false, true],
      ['Intra-State supplies to unregistered persons', false, false]
    ]
    keys.map do |label, reg, inter|
      docs = sales.select { |d| d.registered? == reg && (d.state_code != home_state) == inter }
      {
        description: label,
        nil_rated: docs.sum { |d| d.slabs.reject { |s| s.rate.positive? }.sum(&:taxable) }.round(2),
        exempted: 0.0,
        non_gst: docs.sum { |d| d.record.delivery_charge.to_f }.round(2)
      }
    end
  end

  def hsn_rows(registered)
    groups = {}
    sales.select { |d| d.registered? == registered }.each do |doc|
      inter = doc.state_code != home_state
      doc.record.invoice_items.each do |item|
        hsn = item.product&.hsn_code.to_s.strip
        uqc, qty = uqc_and_quantity(item)
        rate = gst_rate(item.product)
        taxable = item.quantity.to_f * item.unit_price.to_f
        tax = (taxable * rate / 100).round(2)
        g = (groups[[hsn, uqc, rate]] ||= { hsn: hsn, description: '', uqc: uqc, quantity: 0.0, value: 0.0, rate: rate,
                                            taxable: 0.0, igst: 0.0, cgst: 0.0, sgst: 0.0 })
        g[:quantity] += qty
        g[:value] += taxable + tax
        g[:taxable] += taxable
        if inter
          g[:igst] += tax
        else
          half = (tax / 2).round(2)
          g[:cgst] += half
          g[:sgst] += tax - half
        end
      end
    end
    groups.values.each { |g| %i[quantity value taxable igst cgst sgst].each { |k| g[k] = g[k].round(2) } }
          .sort_by { |g| [g[:hsn].blank? ? 1 : 0, g[:hsn], g[:rate]] }
  end

  def docs_rows
    rows = []
    if all_invoices.any?
      numbers = all_invoices.map(&:invoice_number).sort_by { |n| natural_key(n) }
      rows << { nature: 'Invoices for outward supply', from: numbers.first, to: numbers.last,
                total: all_invoices.size, cancelled: cancelled_invoices.size }
    end
    if sales_returns.any?
      numbers = sales_returns.map(&:number).sort
      rows << { nature: 'Credit Note', from: numbers.first, to: numbers.last, total: numbers.size, cancelled: 0 }
    end
    rows
  end

  def summary
    {
      invoices: sales.size, cancelled: cancelled_invoices.size,
      b2b: b2b_sales.size, b2c: b2c_sales.size,
      sales: totals(sales), returns: totals(sales_returns), purchase_returns: totals(purchase_returns)
    }
  end

  private

  def build_invoice_doc(invoice)
    booking = bookings_by_number[invoice.invoice_number]
    gstin = registered_gstin(booking, invoice.customer)
    state = gstin ? gstin[0, 2] : home_state
    slabs = slabs_for(invoice.invoice_items.map { |i| [gst_rate(i.product), i.quantity.to_f * i.unit_price.to_f] },
                      inter: state != home_state, tax_inclusive: false)
    value = slabs.sum { |s| s.taxable + s.tax } + invoice.delivery_charge.to_f - invoice.discount_amount.to_f
    Doc.new(number: invoice.invoice_number, date: invoice.invoice_date, gstin: gstin,
            name: invoice.customer&.display_name.presence || booking&.customer_name.presence || 'Walk-in Customer',
            state_code: state, value: value.round(2), slabs: slabs, record: invoice, kind: :invoice)
  end

  # Credit note amounts are booking prices, which are GST-inclusive.
  def build_credit_doc(cn)
    booking = cn.booking
    gstin = registered_gstin(booking, cn.customer)
    state = gstin ? gstin[0, 2] : home_state
    slabs = slabs_for(cn.credit_note_items.map { |i| [gst_rate(i.product), i.amount.to_f] },
                      inter: state != home_state, tax_inclusive: true)
    Doc.new(number: cn.credit_note_number, date: cn.credit_date, gstin: gstin,
            name: cn.customer_display_name, state_code: state, value: cn.total_amount.to_f.round(2),
            slabs: slabs, record: cn, kind: :credit_note)
  end

  def build_debit_doc(dn)
    gstin = valid_gstin(dn.vendor&.gst_no)
    state = gstin ? gstin[0, 2] : home_state
    slabs = slabs_for(dn.debit_note_items.map { |i| [gst_rate(i.product), i.amount.to_f] },
                      inter: state != home_state, tax_inclusive: true)
    Doc.new(number: dn.debit_note_number, date: dn.debit_date, gstin: gstin,
            name: dn.vendor&.name.to_s, state_code: state, value: dn.total_amount.to_f.round(2),
            slabs: slabs, record: dn, kind: :debit_note)
  end

  # lines: [[rate, amount]]. Groups by rate; 0% first, then ascending.
  def slabs_for(lines, inter:, tax_inclusive:)
    lines.group_by(&:first).sort_by { |rate, _| rate }.map do |rate, ls|
      taxable = 0.0
      tax = 0.0
      ls.each do |_, amount|
        base = tax_inclusive ? amount * 100 / (100 + rate) : amount
        taxable += base
        tax += (base * rate / 100).round(2)
      end
      tax = tax.round(2)
      cgst = inter ? 0.0 : (tax / 2).round(2)
      Slab.new(rate: rate, taxable: taxable.round(2), cgst: cgst,
               sgst: inter ? 0.0 : (tax - cgst).round(2), igst: inter ? tax : 0.0)
    end
  end

  # Same rate the invoice page uses.
  def gst_rate(product)
    return 0.0 unless product&.gst_enabled
    rate = if product.cgst_percentage.present? && product.sgst_percentage.present?
             product.cgst_percentage.to_f + product.sgst_percentage.to_f + product.igst_percentage.to_f
           else
             product.gst_percentage.to_f
           end
    rate.round(2)
  end

  def registered_gstin(booking, customer)
    valid_gstin(booking&.is_b2b ? booking.gstin : nil) || valid_gstin(booking&.gstin) || valid_gstin(customer&.gst_no)
  end

  def valid_gstin(value)
    v = value.to_s.strip.upcase.delete(' ')
    v.match?(GSTIN_FORMAT) ? v : nil
  end

  # Variant lines are reported in the variant's own unit (2 × 5 Kg = 10 KGS).
  def uqc_and_quantity(item)
    if (variant = item.product_variant)
      [UQC.fetch(variant.unit.to_s.downcase, 'OTH-OTHERS'), item.quantity.to_f * variant.weight.to_f]
    else
      [UQC.fetch(item.product&.unit_type.to_s.downcase, 'OTH-OTHERS'), item.quantity.to_f]
    end
  end

  def natural_key(number)
    number.to_s.scan(/\d+|\D+/).map { |p| p =~ /\d/ ? p.rjust(12, '0') : p }.join
  end
end
