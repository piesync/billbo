# This Service handles creating and updating Stripe subscriptions,
# because these 2 actions have VAT/invoice consequences.
class StripeService

  # customer_id - Stripe customer id.
  def initialize(customer_id:)
    @customer_id = customer_id
  end

  # Creates a subscription in Stripe with the appropriate tax_percent.
  #
  # options - All options that can be passed to Stripe subscription create.
  #
  # Returns the created Stripe subscription and invoice.
  def create_subscription(options)
    # This call automatically creates an invoice, always.
    customer.subscriptions.create({
      tax_percent: calculate_vat_rate
    }.merge(options))
  end

  # Calculates the final correct state of an invoice. It
  # figures out the right amount of VAT and discount.
  #
  # stripe_invoice - The Stripe invoice to calculate.
  #
  # Returns a hash that contains all calculated data.
  def calculate_final(stripe_invoice:)
    # Find the VAT invoice item.
    vat_line = stripe_invoice.lines.find { |line| line.metadata[:type] == 'vat' }
    other_lines = stripe_invoice.lines.to_a - [vat_line]
    subtotal = other_lines.map(&:amount).inject(:+)
    total = stripe_invoice.total

    # Recalculate discount based on the sum of all lines besides the vat line.
    discount = calculate_discount(subtotal, calculate_vat_rate, total) if stripe_invoice.discount

    # we do #to_i here because discount can be nil.
    subtotal_after_discount = subtotal - discount.to_i

    # If there is vat and a discount, we need to recalculate VAT and the discount.
    calculation = if vat_line && stripe_invoice.discount
      # Recalculate VAT based on the total after discount
      vat_amount, vat_rate = calculate_vat(subtotal_after_discount).to_a

      {
        discount_amount: discount,
        subtotal_after_discount: subtotal_after_discount,
        vat_amount: vat_amount,
        vat_rate: vat_rate
      }
    else
      {
        discount_amount: stripe_invoice.subtotal - stripe_invoice.total,
        subtotal_after_discount: subtotal_after_discount,
        vat_amount: (vat_line && vat_line.amount).to_i,
        vat_rate: (vat_line && vat_line.metadata[:rate]).to_i
      }
    end

    calculation.merge! \
      subtotal: subtotal,
      total: stripe_invoice.total,
      currency: stripe_invoice.currency
  end

  # Gets metadata for the customer.
  def customer_metadata
    customer.metadata.to_h.merge!(email: customer.email)
  end

  private

  def calculate_vat(amount)
    vat_service.calculate \
      amount: amount,
      country_code: customer.metadata[:country_code],
      vat_registered: (customer.metadata[:vat_registered] == 'true')
  end

  def calculate_vat_rate
    vat_service.vat_rate \
      country_code: customer.metadata[:country_code],
      vat_registered: (customer.metadata[:vat_registered] == 'true')
  end

  # Calculates the amount of discount given on an amount
  # with a certain Stripe coupon.
  #
  # We calculate discount using this formula:
  # d = [ s*( 1 + vr ) - t ] / ( 1 + vr )
  # where s is the amount, vr the VAT rate and t the total amount.
  #
  # Returns discount rounded up to 1 cent.
  def calculate_discount(s, vat_rate, t)
    vr = vat_rate/100.0

    d = (s * (1 + vr) - t)/(1 + vr)
    d.round
  end

  def customer
    @customer ||= Stripe::Customer.retrieve(@customer_id)
  end

  def vat_service
    @vat_service ||= VatService.new
  end
end
