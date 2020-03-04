class InvoiceService
  OrphanRefund = Class.new(StandardError)

  # customer_id - Stripe customer id.
  def initialize(customer_id:)
    @customer_id = customer_id
  end

  # An internal invoice is not created, we only do this when
  # the invoice gets paid (#process_payment)
  def create_subscription(options)
    stripe_service.create_subscription(options)
  end

  def process_payment(stripe_event_id:, stripe_invoice_id:)
    stripe_invoice = Stripe::Invoice.retrieve(stripe_invoice_id)

    # If the invoice only has zero total invoice lines, do not include it for
    # bookkeeping. This happens when a customer subscribes when still in trial.
    return if stripe_invoice.lines.map(&:amount).all?(&:zero?)

    # Get/create an internal invoice and a Stripe invoice.
    invoice = ensure_invoice(
      stripe_event_id,
      stripe_invoice_id
    )

    invoice.finalize!

    # Take snapshots for immutable invoice.
    snapshot_invoice(stripe_invoice, invoice)
    invoice.update(customer_metadata(invoice))

    # Take a snapshot of the card used to make payment.
    # Note: There will be no charge when the invoice was
    # paid with the balance.
    if stripe_invoice.charge
      charge = Stripe::Charge.retrieve(stripe_invoice.charge)
      # Old subscription will have a source, however, new subscriptions use payment methods instead
      card = charge.source || charge.payment_method_details.card
      snapshot_card(card, invoice)
    end

    invoice
  rescue Invoice::AlreadyFinalized
  end

  def process_refund(stripe_event_id:, stripe_invoice_id:)
    invoice = Invoice.first(stripe_id: stripe_invoice_id)

    if invoice
      Invoice.create(
        customer_metadata(invoice).
          merge(
            stripe_event_id: stripe_event_id,
            reference_number: invoice.number,
            credit_note: true
          )
      ).finalize!
    else
      raise OrphanRefund
    end
  end

  def last_stripe_invoice
    Stripe::Invoice.list(customer: @customer_id, limit: 1).first
  end

private

  def customer_metadata(invoice)
    metadata = stripe_service.customer_metadata.slice(
      :email, :name, :company_name, :country_code, :address, :vat_registered, :vat_number, :accounting_id, :ip_address)

    # Transform vat_registered into boolean
    metadata[:vat_registered] = metadata[:vat_registered] == 'true'

    # Prepend :customer
    customer_metadata = metadata.map do |k,v|
      ["customer_#{k}".to_sym, v]
    end.to_h

    # Add the customer id
    customer_metadata[:stripe_customer_id] = @customer_id

    customer_metadata
  end

  def snapshot_invoice(stripe_invoice, invoice)
    # In Stripe: total = subtotal - discount + tax
    invoice.total = stripe_invoice.total.to_i
    invoice.subtotal = stripe_invoice.subtotal.to_i
    invoice.subtotal_after_discount = stripe_invoice.total.to_i - stripe_invoice.tax.to_i
    invoice.discount_amount = stripe_invoice.tax.to_i + stripe_invoice.subtotal.to_i - stripe_invoice.total.to_i
    invoice.vat_amount = stripe_invoice.tax.to_i
    invoice.vat_rate = stripe_invoice.tax_percent
    invoice.currency = stripe_invoice.currency

    # The invoice interval (month/year) is the current interval
    # of the subscription attached to the invoice.
    if subscription_id = stripe_invoice.subscription
      subscription = Stripe::Subscription.retrieve(subscription_id)

      invoice.interval = subscription.plan.interval
      invoice.stripe_subscription_id = subscription.id
    end
  end

  def snapshot_card(card, invoice)
    invoice.update(
      card_brand: card.brand,
      card_last4: card.last4,
      card_country_code: card.country
    )
  end

  def ensure_invoice(stripe_event_id, stripe_invoice_id)
    if invoice = Invoice.find(stripe_id: stripe_invoice_id)
      invoice
    else
      Invoice.create(
        stripe_id: stripe_invoice_id,
        stripe_event_id: stripe_event_id
      )
    end
  end

  def stripe_service
    @stripe_service ||= StripeService.new(customer_id: @customer_id)
  end
end
