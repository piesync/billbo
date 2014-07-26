# This Service handles creating and updating Stripe subscriptions,
# because these 2 actions have VAT/invoice consequences.
class VatSubscriptionService

  # customer_id - Stripe customer id.
  def initialize(customer_id:)
    @customer_id = customer_id
  end

  # When creating a subscription in Stripe, and invoice is created,
  # and paid (charged) IMMEDIATELY. This would result in an invoice
  # without VAT charges.
  #
  # Our solution is to first add VAT charges to the upcoming invoice
  # and then subscribing the customer to the plan.
  #
  # options - All options that can be passed to Stripe subscription create.
  #
  # Returns the created Stripe subscription.
  def create_subscription(options)
    # Get the plan.
    plan = Stripe::Plan.retrieve(options[:plan])
    # Add vat charges.
    # TK what if subscription fails?
    vat = charge_vat_of(plan.amount, currency: plan.currency)
    # Start subscription.
    customer.subscriptions.create(options)
    # Get the last invoice to add metadata snapshot.
    # TK This is tricky, does this always generate an invoice? What about second subscription.
    last_invoice = Stripe::Invoice.all(
      customer: customer.id, limit: 1).first
    snapshot(last_invoice, vat_amount: vat.amount, vat_rate: vat.rate)
  end

  # Applies VAT to a Stripe invoice if necessary.
  # Copies customer metadata to the invoice, to make it immutable
  # for the invoice (in case the customer's metadata changes).
  #
  # invoice - A Stripe invoice object.
  #
  # Returns the finalized stripe invoice.
  def apply_vat(stripe_invoice)
    # Check if VAT has already been applied.
    invoice = Invoice.find_or_create_from_stripe(stripe_id: stripe_invoice.id)
    return stripe_invoice if invoice.added_vat?

    # Add VAT to the invoice.
    vat = charge_vat_of(stripe_invoice.total, invoice_id: stripe_invoice.id)

    # Confirm VAT has been added.
    invoice.added_vat!

    # Snapshot.
    snapshot(stripe_invoice, vat_amount: vat.amount, vat_rate: vat.rate)

    stripe_invoice
  end

  private

  # Charges VAT for a certain amount.
  #
  # amount - Amount to charge VAT for.
  # invoice_id - optional invoice_id (upcoming invoice by default).
  #
  # Returns a VatCharge object.
  def charge_vat_of(amount, currency: 'usd', invoice_id: nil)
    # Calculate the amount of VAT to be paid.
    vat = vat_service.calculate \
      amount: amount,
      country_code: customer.metadata[:country_code],
      is_company: (customer.metadata[:is_company] == 'true')

    # Add an invoice item to the invoice with this amount.
    Stripe::InvoiceItem.create(
      customer: customer.id,
      invoice: invoice_id,
      amount: vat.amount,
      currency: currency,
      description: "VAT (#{vat.rate}%)"
    ) unless vat.amount.zero?

    vat
  end

  # Adds a snapshot of the customer metadata to the invoice.
  #
  # invoice - A Stripe invoice object.
  #
  # Returns the Stripe invoice
  def snapshot(invoice, extra = {})
    invoice.metadata = customer.metadata.to_h.merge(extra)
    invoice.save
  end

  def customer
    @customer ||= Stripe::Customer.retrieve(@customer_id)
  end

  def vat_service
    @vat_service ||= VatService.new
  end
end
