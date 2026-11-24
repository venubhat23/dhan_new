# Zoho-Books-style Profit & Loss statement built from this app's own records.
#
#   Operating Income   Sales (bookings, ex-GST, after line discounts)
#                      Discount (order-level bulk discount, ex-GST, negative)
#                      Shipping Charges
#                      Sales Returns (credit notes, ex-GST, negative)
#   Cost of Goods Sold qty sold × unit cost  minus  qty returned × unit cost
#   Operating Expense  Expense rows grouped by category + Staff Payments
#   Manual Journals    Published journal lines on income / COGS / expense /
#                      other-income / other-expense accounts land in the matching
#                      section (merged by name into an existing line), honouring
#                      the journal's reporting method for the chosen basis.
#   Non Operating      Expense category "Withdrawal for Self" is drawings, not an
#                      expense, and "Inventory Purchase" is already in COGS, so
#                      both are left out.
#
# Basis:
#   accrual – a booking counts on its booking_date, whatever its payment state.
#   cash    – only paid bookings count, on payment_completed_at (or booking_date).
# Expenses, staff payments and credit notes are dated by their own date in both.
#
# Item prices are GST-inclusive (see Booking#calculate_totals), so every income
# figure has GST stripped out: GST collected is a liability, not income.
class ProfitLossReport
  EXCLUDED_BOOKING_STATUSES = %w[cancelled returned refund].freeze
  NON_EXPENSE_CATEGORIES    = ['Inventory Purchase', 'Withdrawal for Self'].freeze
  SALARY_CATEGORY           = 'Staff Salaries'.freeze

  DATE_RANGES = [
    ['today',            'Today'],
    ['this_week',        'This Week'],
    ['this_month',       'This Month'],
    ['this_quarter',     'This Quarter'],
    ['this_year',        'This Year'],
    ['month_to_date',    'Month To Date'],
    ['quarter_to_date',  'Quarter To Date'],
    ['year_to_date',     'Year To Date'],
    ['previous_day',     'Previous Day'],
    ['previous_week',    'Previous Week'],
    ['previous_month',   'Previous Month'],
    ['previous_quarter', 'Previous Quarter'],
    ['previous_year',    'Previous Year'],
    ['custom',           'Custom']
  ].freeze

  COMPARE_OPTIONS = [
    ['none',            'None'],
    ['previous_period', 'Previous Period(s)'],
    ['previous_year',   'Previous Year(s)']
  ].freeze

  Line = Struct.new(:key, :name, :amount, keyword_init: true)

  attr_reader :from_date, :to_date, :basis, :store_id

  def initialize(from_date:, to_date:, basis: 'accrual', store_id: nil)
    @from_date = from_date
    @to_date   = to_date
    @basis     = basis == 'cash' ? 'cash' : 'accrual'
    @store_id  = store_id.presence
  end

  # ---- Date ranges (Indian financial year: 1 Apr – 31 Mar) -------------------

  def self.fy_start(date)
    year = date.month >= 4 ? date.year : date.year - 1
    Date.new(year, 4, 1)
  end

  # Financial quarters: Apr–Jun, Jul–Sep, Oct–Dec, Jan–Mar (same as calendar
  # quarters shifted, so Date#beginning_of_quarter already lines up).
  def self.range_for(key, today = Date.current)
    case key
    when 'today'            then [today, today]
    when 'this_week'        then [today.beginning_of_week, today.end_of_week]
    when 'this_month'       then [today.beginning_of_month, today.end_of_month]
    when 'this_quarter'     then [today.beginning_of_quarter, today.end_of_quarter]
    when 'this_year'        then [fy_start(today), fy_start(today) + 1.year - 1.day]
    when 'month_to_date'    then [today.beginning_of_month, today]
    when 'quarter_to_date'  then [today.beginning_of_quarter, today]
    when 'year_to_date'     then [fy_start(today), today]
    when 'previous_day'     then [today - 1, today - 1]
    when 'previous_week'    then [(today - 1.week).beginning_of_week, (today - 1.week).end_of_week]
    when 'previous_month'   then [today.prev_month.beginning_of_month, today.prev_month.end_of_month]
    when 'previous_quarter' then [(today - 3.months).beginning_of_quarter, (today - 3.months).end_of_quarter]
    when 'previous_year'    then [fy_start(today) - 1.year, fy_start(today) - 1.day]
    end
  end

  # Same-length window immediately before [from, to] (whole months stay whole months).
  def self.previous_period(from, to)
    if from == from.beginning_of_month && to == to.end_of_month
      months = (to.year * 12 + to.month) - (from.year * 12 + from.month) + 1
      [from - months.months, (from - 1.day)]
    else
      days = (to - from).to_i + 1
      [from - days, from - 1]
    end
  end

  # ---- Statement ------------------------------------------------------------

  def operating_income
    @operating_income ||= [
      Line.new(key: 'sales',         name: 'Sales',                   amount: sales_total),
      Line.new(key: 'discount',      name: 'Discount',                amount: -discount_total),
      Line.new(key: 'shipping',      name: 'Shipping Charge',         amount: shipping_total),
      Line.new(key: 'sales_returns', name: 'Sales Returns (Credit Notes)', amount: -returns_total)
    ].reject { |l| l.amount.zero? && l.key != 'sales' }
    merge_journal_lines(@operating_income, %w[income])
  end

  def cost_of_goods_sold
    @cost_of_goods_sold ||= merge_journal_lines([
      Line.new(key: 'cogs', name: 'Cost of Goods Sold', amount: cogs_total)
    ], %w[cost_of_goods_sold])
  end

  def operating_expense
    @operating_expense ||= begin
      by_cat = expense_scope.where.not(category: NON_EXPENSE_CATEGORIES).group(:category).sum(:amount)
                            .transform_values(&:to_f)
      salaries = by_cat.delete(SALARY_CATEGORY).to_f + staff_payment_scope.sum(:amount).to_f
      lines = by_cat.sort_by { |cat, _| cat }.map do |cat, amt|
        Line.new(key: "expense:#{cat}", name: cat, amount: amt)
      end
      lines << Line.new(key: 'salaries', name: 'Salaries and Employee Wages', amount: salaries) if salaries.nonzero?
      merge_journal_lines(lines, %w[expense]).sort_by(&:name)
    end
  end

  def non_operating_income  = (@non_operating_income  ||= merge_journal_lines([], %w[other_income]).sort_by(&:name))
  def non_operating_expense = (@non_operating_expense ||= merge_journal_lines([], %w[other_expense]).sort_by(&:name))

  def total_operating_income  = sum(operating_income)
  def total_cogs              = sum(cost_of_goods_sold)
  def gross_profit            = total_operating_income - total_cogs
  def total_operating_expense = sum(operating_expense)
  def operating_profit        = gross_profit - total_operating_expense
  def total_non_operating_income  = sum(non_operating_income)
  def total_non_operating_expense = sum(non_operating_expense)
  def net_profit = operating_profit + total_non_operating_income - total_non_operating_expense

  # Flat {key => amount} for comparison columns.
  def amounts
    lines = operating_income + cost_of_goods_sold + operating_expense + non_operating_income + non_operating_expense
    lines.to_h { |l| [l.key, l.amount] }.merge(
      'total_operating_income' => total_operating_income,
      'total_cogs' => total_cogs,
      'gross_profit' => gross_profit,
      'total_operating_expense' => total_operating_expense,
      'operating_profit' => operating_profit,
      'total_non_operating_income' => total_non_operating_income,
      'total_non_operating_expense' => total_non_operating_expense,
      'net_profit' => net_profit
    )
  end

  # ---- Drill-down transactions ---------------------------------------------
  # Returns [{date:, reference:, party:, description:, amount:, link: [type, record]}]

  def transactions_for(key)
    amounts # build every section so journal aliases are known
    rows = base_transactions_for(key)
    ids = key.to_s.start_with?('account:') ? [key.to_s.split(':').last.to_i] : journal_aliases.fetch(key, [])
    (rows + journal_rows(ids)).reject { |r| r[:amount].to_f.zero? }.sort_by { |r| r[:date] || Date.new(1900) }
  end

  def base_transactions_for(key)
    case key
    when 'sales'
      booking_rows { |b, f| f[:sales] }
    when 'discount'
      booking_rows { |b, f| -f[:discount] }
    when 'shipping'
      booking_rows { |b, f| f[:shipping] }
    when 'sales_returns'
      credit_note_scope.includes(:booking, credit_note_items: [:product, { booking_item: [:product, :product_variant] }]).order(:credit_date).map do |cn|
        { date: cn.credit_date, reference: cn.credit_note_number, party: cn.customer_display_name,
          description: "Return against Booking ##{cn.booking&.booking_number}",
          amount: -credit_note_ex_gst(cn), link: [:credit_note, cn] }
      end
    when 'cogs'
      cogs_rows
    when 'salaries'
      expense_rows(expense_scope.where(category: SALARY_CATEGORY)) +
        staff_payment_scope.includes(:staff_member).order(:payment_date).map do |sp|
          { date: sp.payment_date, reference: "Salary #{Date::ABBR_MONTHNAMES[sp.month]} #{sp.year}",
            party: sp.staff_member&.name, description: sp.notes, amount: sp.amount.to_f, link: nil }
        end
    when /\Aexpense:(.+)\z/
      expense_rows(expense_scope.where(category: Regexp.last_match(1)))
    else
      []
    end
  end

  def self.account_name(key)
    case key
    when 'sales' then 'Sales'
    when 'discount' then 'Discount'
    when 'shipping' then 'Shipping Charge'
    when 'sales_returns' then 'Sales Returns (Credit Notes)'
    when 'cogs' then 'Cost of Goods Sold'
    when 'salaries' then 'Salaries and Employee Wages'
    when /\Aexpense:(.+)\z/ then Regexp.last_match(1)
    when /\Aaccount:(\d+)\z/ then LedgerAccount.find_by(id: Regexp.last_match(1))&.name || 'Account'
    else key.to_s.humanize
    end
  end

  private

  # -- Manual journals --

  def journal_line_scope
    scope = ManualJournalLine.joins(:manual_journal, :ledger_account)
                             .merge(ManualJournal.published.manual_only.for_basis(basis))
                             .where(manual_journals: { journal_date: from_date..to_date })
                             .where(ledger_accounts: { account_type: LedgerAccount::PL_TYPES })
    scope = scope.where(manual_journals: { store_id: store_id }) if store_id
    scope
  end

  # {LedgerAccount => natural amount} for P&L accounts with journal activity.
  def journal_by_account
    @journal_by_account ||= begin
      sums = journal_line_scope.group(:ledger_account_id).pluck(:ledger_account_id, Arel.sql('SUM(manual_journal_lines.debit)'), Arel.sql('SUM(manual_journal_lines.credit)'))
      accounts = LedgerAccount.where(id: sums.map(&:first)).index_by(&:id)
      sums.each_with_object({}) do |(id, dr, cr), h|
        acct = accounts[id]
        next unless acct
        amt = LedgerAccount::CREDIT_NATURE.include?(acct.account_type) ? cr.to_f - dr.to_f : dr.to_f - cr.to_f
        h[acct] = amt.round(2) unless amt.round(2).zero?
      end
    end
  end

  # statement key => [ledger_account_id, ...] whose journal amounts were folded into it
  def journal_aliases = (@journal_aliases ||= {})

  def merge_journal_lines(lines, types)
    journal_by_account.each do |acct, amt|
      next unless types.include?(acct.account_type)
      existing = lines.find { |l| l.name.to_s.casecmp?(acct.name) }
      if existing
        existing.amount = (existing.amount.to_f + amt).round(2)
        (journal_aliases[existing.key] ||= []) << acct.id
      else
        lines << Line.new(key: "account:#{acct.id}", name: acct.name, amount: amt)
      end
    end
    lines
  end

  def journal_rows(account_ids)
    return [] if account_ids.blank?
    journal_line_scope.where(ledger_account_id: account_ids).includes(:manual_journal, :ledger_account).map do |l|
      j = l.manual_journal
      { date: j.journal_date, reference: "Journal ##{j.journal_number}#{" (#{j.reference_number})" if j.reference_number.present?}",
        party: l.contact_name.presence, description: [l.description.presence, j.notes].compact.first,
        amount: l.natural_amount.round(2), link: [:manual_journal, j] }
    end
  end

  def sum(lines) = lines.sum(&:amount).to_f.round(2)

  def range = from_date.beginning_of_day..to_date.end_of_day

  # -- Bookings --

  def booking_scope
    scope = Booking.where.not(status: EXCLUDED_BOOKING_STATUSES)
    scope = scope.where(store_id: store_id) if store_id
    if basis == 'cash'
      scope.where(payment_status: 'paid')
           .where('COALESCE(bookings.payment_completed_at, bookings.booking_date) BETWEEN ? AND ?',
                  range.begin, range.end)
    else
      scope.where(booking_date: range)
    end
  end

  # Per-booking figures. subtotal is already ex-GST and net of line discounts;
  # the bulk discount is entered GST-inclusive, so its GST share is removed in
  # the same proportion as the booking's tax.
  def booking_figures(subtotal, tax, discount, shipping)
    subtotal = subtotal.to_f
    gross    = subtotal + tax.to_f
    disc     = discount.to_f
    disc_ex  = gross.positive? ? disc * subtotal / gross : disc
    { sales: subtotal, discount: disc_ex, shipping: shipping.to_f }
  end

  def booking_totals
    @booking_totals ||= begin
      t = { sales: 0.0, discount: 0.0, shipping: 0.0 }
      booking_scope.pluck(:subtotal, :tax_amount, :discount_amount, :shipping_charges).each do |s, tx, d, sh|
        booking_figures(s, tx, d, sh).each { |k, v| t[k] += v }
      end
      t.transform_values { |v| v.round(2) }
    end
  end

  def sales_total    = booking_totals[:sales]
  def discount_total = booking_totals[:discount]
  def shipping_total = booking_totals[:shipping]

  def booking_rows
    booking_scope.order(:booking_date).map do |b|
      { date: b.booking_date&.to_date, reference: b.booking_number, party: b.customer_name,
        description: Booking.status_label(b.status), amount: yield(b, booking_figures(b.subtotal, b.tax_amount, b.discount_amount, b.shipping_charges)).round(2),
        link: [:booking, b] }
    end
  end

  # -- Credit notes --

  def credit_note_scope
    scope = CreditNote.joins(:booking).where(credit_date: from_date..to_date)
                      .where.not(bookings: { status: EXCLUDED_BOOKING_STATUSES })
    scope = scope.where(store_id: store_id) if store_id
    scope
  end

  def gst_rate(product)
    product&.gst_enabled && product.gst_percentage.to_f.positive? ? product.gst_percentage.to_f : 0.0
  end

  def credit_note_ex_gst(cn)
    cn.credit_note_items.sum do |i|
      rate = i.booking_item&.bulk_gst_exempt? ? 0.0 : gst_rate(i.product)
      i.amount.to_f * 100 / (100 + rate)
    end.round(2)
  end

  def returns_total
    @returns_total ||= credit_note_scope.includes(credit_note_items: [:product, { booking_item: [:product, :product_variant] }]).sum { |cn| credit_note_ex_gst(cn) }.round(2)
  end

  # -- Cost of goods sold --

  def unit_cost(product, variant)
    [variant&.buying_price, variant&.purchase_price, product&.buying_price, product&.purchase_price]
      .map(&:to_f).find(&:positive?) || 0.0
  end

  def sold_items
    BookingItem.where(booking_id: booking_scope.select(:id)).includes(:product, :product_variant, :booking)
  end

  def returned_items
    CreditNoteItem.where(credit_note_id: credit_note_scope.select(:id)).includes(:product, :product_variant, :credit_note)
  end

  def cogs_total
    @cogs_total ||= begin
      sold = sold_items.sum { |i| i.quantity.to_f * unit_cost(i.product, i.product_variant) }
      back = returned_items.sum { |i| i.quantity.to_f * unit_cost(i.product, i.product_variant) }
      (sold - back).round(2)
    end
  end

  def cogs_rows
    sold = sold_items.map do |i|
      cost = unit_cost(i.product, i.product_variant)
      { date: i.booking&.booking_date&.to_date, reference: i.booking&.booking_number,
        party: item_name(i), description: "#{fmt_qty(i.quantity)} × ₹#{format('%.2f', cost)}",
        amount: (i.quantity.to_f * cost).round(2), link: [:booking, i.booking] }
    end
    back = returned_items.map do |i|
      cost = unit_cost(i.product, i.product_variant)
      { date: i.credit_note&.credit_date, reference: i.credit_note&.credit_note_number,
        party: item_name(i), description: "Returned #{fmt_qty(i.quantity)} × ₹#{format('%.2f', cost)}",
        amount: -(i.quantity.to_f * cost).round(2), link: [:credit_note, i.credit_note] }
    end
    sold + back
  end

  def item_name(i)
    i.product_variant ? "#{i.product&.name} (#{i.product_variant.try(:label)})" : i.product&.name
  end

  def fmt_qty(q) = q.to_f.to_s.sub(/\.0\z/, '')

  # -- Expenses --

  def expense_scope
    scope = Expense.where(expense_date: from_date..to_date)
    scope = scope.where(store_id: store_id) if store_id
    scope
  end

  def staff_payment_scope
    scope = StaffPayment.where(payment_date: from_date..to_date)
    scope = scope.joins(:staff_member).where(staff_members: { store_id: store_id }) if store_id
    scope
  end

  def expense_rows(scope)
    scope.includes(:store).order(:expense_date).map do |e|
      { date: e.expense_date, reference: e.title, party: e.store&.name,
        description: e.description, amount: e.amount.to_f, link: nil }
    end
  end
end
