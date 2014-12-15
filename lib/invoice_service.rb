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
    snapshot_customer(invoice)

    subscription
  end

  def ensure_vat(stripe_invoice_id:)
    # Get/create an internal invoice.
    invoice = ensure_invoice(stripe_invoice_id)

    # Only apply VAT if not applied yet.
    if !invoice.added_vat?
      stripe_invoice = stripe_service.apply_vat(invoice_id: stripe_invoice_id)
      invoice.added_vat!
      snapshot_customer(invoice)
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
    # Do a final calculation of the invoice amounts.
    invoice.update(stripe_service.calculate_final(stripe_invoice: stripe_invoice))

    # Take a snapshot of the card used to make payment.
    # Note: There will be no charge in two cases:
    #   1. The invoice total is 0 so no charge is needed.
    #   2. The invoice could be paid with credit.
    #
    if stripe_invoice.charge
      charge = Stripe::Charge.retrieve(stripe_invoice.charge)
      snapshot_card(charge.card, invoice)
    end

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

  def snapshot_customer(invoice)
    metadata = stripe_service.customer_metadata.slice(
      :email, :name, :company_name, :country_code, :address, :vat_number, :accounting_id, :ip_address)

    # Prepend :customer
    customer_metadata = metadata.map do |k,v|
      ["customer_#{k}".to_sym, v]
    end.to_h

    # Add the customer id
    customer_metadata[:stripe_customer_id] = @customer_id

    # Save to invoice
    invoice.update(customer_metadata)
  end

  def snapshot_card(card, invoice)
    invoice.update(
      card_brand: card.brand,
      card_last4: card.last4,
      card_country_code: card.country
    )
  end

  def ensure_invoice(stripe_id)
    Invoice.find_or_create_from_stripe(stripe_id: stripe_id)
  end

  def stripe_service
    @stripe_service ||= StripeService.new(customer_id: @customer_id)
  end
end
