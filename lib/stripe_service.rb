# This Service handles creating and updating Stripe subscriptions,
# because these 2 actions have VAT/invoice consequences.
class StripeService

  # customer_id - Stripe customer id.
  def initialize(customer_id:)
    @customer_id = customer_id
  end

  # When creating a subscription in Stripe, an invoice is created,
  # and paid (charged) IMMEDIATELY. This would result in an invoice
  # without VAT charges.
  #
  # Our solution is to first add VAT charges to the upcoming invoice
  # and then subscribing the customer to the plan.
  #
  # options - All options that can be passed to Stripe subscription create.
  #
  # Returns the created Stripe subscription and invoice.
  def create_subscription(options)
    # Charge VAT in advance because subscription call will create and pay an invoice.
    # TK actually we need to apply VAT for invoiceitems that are pending and scheduled
    # for the next invoice.
    vat, invoice_item = charge_vat_of_plan(options[:plan])

    # Start subscription.
    # This call automatically creates an invoice, always.
    # TK what if subscription has a trial?
    subscription = customer.subscriptions.create(options)

    # The subscription creation has immediately created an invoice as well (only
    #   if this was the first invoice).
    # Get the last invoice to add metadata snapshot.
    _last_invoice = last_invoice
    snapshot(_last_invoice, vat)

    [subscription, _last_invoice]
  rescue Stripe::StripeError => e
    # Something failed in Stripe, if we already charged for VAT,
    # we need to rollback this. As we may charge twice later otherwise.
    invoice_item.delete if invoice_item
    raise e
  end

  # Applies VAT to a Stripe invoice if necessary.
  # Copies customer metadata to the invoice, to make it immutable
  # for the invoice (in case the customer's metadata changes).
  #
  # invoice - A Stripe invoice object.
  #
  # Returns the finalized stripe invoice.
  def apply_vat(invoice_id:)
    stripe_invoice = Stripe::Invoice.retrieve(invoice_id)

    # Add VAT to the invoice.
    vat, invoice_item = charge_vat(stripe_invoice.total,
      invoice_id: invoice_id, currency: stripe_invoice.currency)

    # Snapshot.
    snapshot(stripe_invoice, vat)

    stripe_invoice
  end

  private

  def last_invoice
    Stripe::Invoice.all(customer: customer.id, limit: 1).first
  end

  def charge_vat_of_plan(plan_id)
    # Get the plan.
    plan = Stripe::Plan.retrieve(plan_id)
    # Add vat charges.
    # TK what if subscription fails?
    charge_vat(plan.amount, currency: plan.currency)
  end

  # Charges VAT for a certain amount.
  #
  # amount - Amount to charge VAT for.
  # invoice_id - optional invoice_id (upcoming invoice by default).
  #
  # Returns a VatCharge object.
  def charge_vat(amount, currency:, invoice_id: nil)
    # Calculate the amount of VAT to be paid.
    vat = vat_service.calculate \
      amount: amount,
      country_code: customer.metadata[:country_code],
      is_company: (customer.metadata[:is_company] == 'true')

    # Add an invoice item to the invoice with this amount.
    invoice_item = Stripe::InvoiceItem.create(
      customer: customer.id,
      invoice: invoice_id,
      amount: vat.amount,
      currency: currency,
      description: "VAT (#{vat.rate}%)"
    ) unless vat.amount.zero?

    [vat, invoice_item]
  end

  # Adds a snapshot of the customer metadata to the invoice.
  #
  # invoice - A Stripe invoice object.
  #
  # Returns the Stripe invoice
  def snapshot(invoice, vat, extra = {})
    invoice.metadata = customer.metadata.to_h.merge(
      vat_amount: vat.amount,
      vat_rate: vat.rate
    ).merge(extra)
    invoice.save
  end

  def customer
    @customer ||= Stripe::Customer.retrieve(@customer_id)
  end

  def vat_service
    @vat_service ||= VatService.new
  end
end
