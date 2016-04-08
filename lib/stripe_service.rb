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

  # Gets metadata for the customer.
  def customer_metadata
    customer.metadata.to_h.merge!(email: customer.email)
  end

  private

  def calculate_vat_rate
    country_code = if vat = customer.metadata[:vat_number]
      vat[0..1]
    else
      customer.metadata[:country_code]
    end

    vat_service.vat_rate \
      country_code: country_code,
      vat_registered: (customer.metadata[:vat_registered] == 'true')
  end

  def customer
    @customer ||= Stripe::Customer.retrieve(@customer_id)
  end

  def vat_service
    @vat_service ||= VatService.new
  end
end
