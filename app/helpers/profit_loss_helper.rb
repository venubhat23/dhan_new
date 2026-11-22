module ProfitLossHelper
  # Indian digit grouping like Zoho: 5076760.3 -> "50,76,760.30", negatives as "-1,234.00".
  def pl_amount(amount)
    value = amount.to_f.round(2)
    int, dec = format('%.2f', value.abs).split('.')
    grouped = if int.length > 3
                head = int[0...-3].reverse.scan(/\d{1,2}/).join(',').reverse
                "#{head},#{int[-3..]}"
              else
                int
              end
    "#{'-' if value.negative?}#{grouped}.#{dec}"
  end

  def pl_amount_cell(amount)
    content_tag(:td, pl_amount(amount), class: "num#{' neg' if amount.to_f.negative?}")
  end
end
