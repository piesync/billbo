class TemplateHelper

  def format_money(amount, currency, to = currency)
    Money.new(amount, currency).exchange_to(to)
  end

  def currency_symbol(currency)
    Money::Currency.new(currency).symbol
  end

  def format_date(timestamp)
    at = Time.at(timestamp)
    at.strftime("%B #{at.day.ordinalize}, %Y")
  end

  def country_name(code)
    code && Country.new(code).name
  end
end
