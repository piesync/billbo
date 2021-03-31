require 'forwardable'

class TemplateViewModel
  extend Forwardable

  def initialize(invoice:, stripe_invoice:, stripe_coupon:, reference: nil)
    @invoice = invoice
    @stripe_invoice = stripe_invoice
    @stripe_coupon = stripe_coupon
    @reference = reference
  end

  # Delegate correct methods to underlaying models.
  def_delegators :invoice,
    :number, :paid?, :card_brand, :card_last4, :total, :currency, :finalized_at, :due_at,
    :customer_name, :customer_company_name, :customer_address, :customer_country_code,
    :customer_vat_registered?, :customer_vat_number, :discount?, :discount_amount,
    :subtotal_after_discount, :vat?, :vat_rate, :vat_amount, :vat_amount_eur, :total,
    :total_eur, :eu?, :vat_reverse_charged?

  def_delegators :stripe_invoice, :lines

  def_delegators :configuration,
    :seller_logo_url, :seller_company_name, :seller_address_line1, :seller_address_line2,
    :primary_country, :seller_email, :seller_vat_number, :seller_other_info,
    :seller_bank_name, :seller_bic, :seller_iban

  def credit_note?
    @invoice.credit_note
  end

  def negative_invoice?
    !credit_note? && total.to_i < 0.0
  end

  def document_type
    if credit_note? || total.to_i < 0.0
      'Credit Note'
    else
      'Invoice'
    end
  end

  def invoice_number
    reference.number
  end

  private

  attr_reader :invoice, :reference, :stripe_invoice, :stripe_coupon

  def configuration
    Configuration
  end

  def format_money(amount, currency)
    Money.new(amount, currency).format(sign_before_symbol: true)
  end

  def subscription_line_description(line)
    # If line item has type subscription, then the line metadata is the subscription metadata (version > 2014-11-20)
    description = line.metadata[:description] || Stripe::Product.retrieve(line.plan.product)&.name

    "#{description} (#{format_date(line.period.start)} - #{format_date(line.period.end)})"
  end

  def percent_off
    stripe_coupon.try(:percent_off)
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

