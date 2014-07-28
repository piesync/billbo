class InvoiceService

  # customer_id - Stripe customer id.
  def initialize(customer_id:)
    @customer_id = customer_id
  end

  def create_subscription(options)
    subscription, stripe_invoice = stripe_service.create_subscription(options)

    # If this method was succesful, we created a paid invoice with VAT already applied.
    ensure_invoice(stripe_invoice.id).added_vat!.finalize!

    subscription
  rescue Invoice::AlreadyFinalized
    # Should not happen, except if the invoice.payment_succeeded webhook
    # gets executed before the finalize here. But that's no issue.
    subscription
  end

  def apply_vat(stripe_invoice_id:)
    # Get/create an internal invoice.
    invoice = ensure_invoice(stripe_invoice_id)

    # Only apply VAT if not applied yet.
    if !invoice.added_vat?
      stripe_service.apply_vat(invoice_id: stripe_invoice_id)
      invoice.added_vat!
    end

    invoice
  end

  private

  def ensure_invoice(stripe_id)
    Invoice.find_or_create_from_stripe(stripe_id: stripe_id)
  end

  def stripe_service
    @stripe_service ||= StripeService.new(customer_id: @customer_id)
  end
end
