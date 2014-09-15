class TemplateHelper

  def format_money(amount, currency)
    Money.new(amount, currency).format
  end

  def currency_symbol(currency)
    Money::Currency.new(currency).symbol
  end

  def format_date(timestamp)
    at = Time.at(timestamp)
    at.strftime("%B #{at.day.ordinalize}, %Y")
  end
end
