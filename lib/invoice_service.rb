# There are 2 ways invoices get created in Stripe:
#   1. Creating a subscription which immediately issues a new invoice. This still fires
#      an invoice.created event, but the invoice is not editable anymore. So we need to apply VAT
#      before creating the subscription.
#      It is possible that the invoice.created hook is called before the create_subscription method
#      ends. It this case it is possible that we try to add VAT again, because the added_vat
#      flag is not yet set on the invoice. In this case Stripe::InvalidRequestError will be raised.
#
#   2. At the end of a subscription cycle. This will trigger an invoice.created hook which
#      call the #ensure_vat method. This adds VAT to the invoice.
#
class InvoiceService
  OrphanRefund = Class.new(StandardError)

  # customer_id - Stripe customer id.
  def initialize(customer_id:)
    @customer_id = customer_id
  end

  def create_subscription(options)
    subscription, stripe_invoice = stripe_service.create_subscription(options)

    # If this method was succesful, we created a paid invoice with VAT already applied.
    invoice = ensure_invoice(stripe_invoice.id).added_vat!

    subscription
  end

  def ensure_vat(stripe_invoice_id:)
    # Get/create an internal invoice.
    invoice = ensure_invoice(stripe_invoice_id)

    # Only apply VAT if not applied yet.
    if !invoice.added_vat?
      stripe_invoice = stripe_service.apply_vat(invoice_id: stripe_invoice_id)
      invoice.added_vat!
    end

    invoice
  rescue Stripe::InvalidRequestError
    # This means we could not add VAT because the invoice is not editable anymore.
    # The invoice was probably created through #create_subscription so VAT and snapshotting
    # will be handled there. Nothing to do anymore here.
    invoice
  end

  def process_payment(stripe_invoice_id:)
    # Get/create an internal invoice and a Stripe invoice.
    invoice = ensure_invoice(stripe_invoice_id)
    stripe_invoice = Stripe::Invoice.retrieve(stripe_invoice_id)

    # Finalize the invoice.
    # Unless if the invoice's total amount is 0, then we don't
    # need to make an invoice for it.
    invoice.finalize! unless stripe_invoice.total.zero?

    # Now we are sure nothing is going to change the invoice anymore.
    # Take a final snapshot into the invoice.
    stripe_service.snapshot_final \
      stripe_invoice: stripe_invoice,
      number: invoice.number

    snapshot(stripe_invoice, invoice)

    invoice
  rescue Invoice::AlreadyFinalized
  end

  def process_refund(stripe_invoice_id:)
    invoice = Invoice.first(stripe_id: stripe_invoice_id)

    if invoice
      credit_note = Invoice.create \
        credit_note: true,
        reference_number: invoice.number

      credit_note.finalize!
    else
      raise OrphanRefund
    end
  end

  private

  # Take a snapshot from a Stripe invoice to an internal invoice.
  def snapshot(stripe_invoice, invoice)
    invoice.update \
      subtotal: stripe_invoice.metadata[:subtotal].to_i,
      discount_amount: stripe_invoice.metadata[:discount_amount].to_i,
      subtotal_after_discount: stripe_invoice.metadata[:subtotal_after_discount].to_i,
      vat_amount: stripe_invoice.metadata[:vat_amount].to_i,
      vat_rate: stripe_invoice.metadata[:vat_rate].to_f,
      total: stripe_invoice.total,
      country_code: stripe_invoice.metadata[:country_code],
      vat_number: stripe_invoice.metadata[:vat],
      vat_registered: (stripe_invoice.metadata[:vat_registered] == 'true')
  end

  def ensure_invoice(stripe_id)
    Invoice.find_or_create_from_stripe(stripe_id: stripe_id)
  end

  def stripe_service
    @stripe_service ||= StripeService.new(customer_id: @customer_id)
  end
end
