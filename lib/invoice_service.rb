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

    # There will be no charge when the document was paid with the balance.
    charge = if stripe_invoice.charge
      Stripe::Charge.retrieve(stripe_invoice.charge)
    end

    finalize!(stripe_event_id: stripe_event_id, stripe_object: stripe_invoice, charge: charge)
  end

  def process_credit_note(stripe_event_id:, stripe_credit_note_id:)
    stripe_credit_note = Stripe::CreditNote.retrieve(stripe_credit_note_id)

    # If the amount was actually refunded, get the charge
    charge = if stripe_credit_note.refund
      refund = Stripe::Refund.retrieve(stripe_credit_note.refund)
      Stripe::Charge.retrieve(refund.charge)
    end

    finalize!(stripe_event_id: stripe_event_id, stripe_object: stripe_credit_note, charge: charge)
  end

  def last_stripe_invoice
    Stripe::Invoice.list(customer: @customer_id, limit: 1).first
  end

private

  def finalize!(stripe_event_id:, stripe_object:, charge:)
    # If the document only has zero total lines, do not include it for bookkeeping.
    # This happens when a customer subscribes when still in trial or no refund lines were set.
    return if stripe_object.lines.map(&:amount).all?(&:zero?)

    attributes = {}

    if stripe_object.is_a?(Stripe::CreditNote)
      invoice = Invoice.first(stripe_id: stripe_object.invoice)
      raise OrphanRefund unless invoice

      attributes.merge!({
        reference_number: invoice.number,
        credit_note: true
      })
    end

    # Take snapshots for immutable document.
    attributes.merge!(snapshot_document(stripe_object))
    attributes.merge!(snapshot_customer_metadata)

    # Take a snapshot of the card used to make payment.
    if charge
      # Old subscription will have a source, however, new subscriptions use payment methods instead
      card = charge.source || charge.payment_method_details.card
      attributes.merge!(snapshot_card(card))
    end

    # Get/create an internal document and a Stripe document.
    document = ensure_document(
      stripe_event_id,
      stripe_object.id
    )

    # Set the document attributes we collected.
    document.update(attributes)

    # Finalize now that we have a complete document
    document.finalize!

    document
  rescue Invoice::AlreadyFinalized
  end

  def snapshot_customer_metadata
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

  def snapshot_document(stripe_object)
    props = {}
    # In Stripe: total = subtotal - discount + tax
    props[:total] = stripe_object.total.to_i
    props[:subtotal] = stripe_object.subtotal.to_i
    props[:vat_amount] = stripe_object.is_a?(Stripe::Invoice) ? stripe_object.tax.to_i : stripe_object.tax_amounts.sum(&:amount).to_i
    props[:vat_rate] = if stripe_object.is_a?(Stripe::Invoice)
      stripe_object.tax_percent
    else
      invoice = Invoice.first(stripe_id: stripe_object.invoice)
      invoice.vat_rate
    end
    props[:subtotal_after_discount] = props[:total] - props[:vat_amount]
    props[:discount_amount] = props[:vat_amount] + props[:subtotal] - props[:total]
    props[:currency] = stripe_object.currency

    # The invoice interval (month/year) is the current interval
    # of the subscription attached to the invoice.
    if stripe_object.is_a?(Stripe::Invoice) && subscription_id = stripe_object.subscription
      subscription = Stripe::Subscription.retrieve(subscription_id)

      props[:interval] = subscription.plan.interval
      props[:stripe_subscription_id] = subscription.id
    end

    props
  end

  def snapshot_card(card)
    {
      card_brand: card.brand,
      card_last4: card.last4,
      card_country_code: card.country
    }
  end

  def ensure_document(stripe_event_id, stripe_id)
    if invoice = Invoice.find(stripe_id: stripe_id)
      invoice
    else
      Invoice.create(
        stripe_id: stripe_id,
        stripe_event_id: stripe_event_id
      )
    end
  end

  def stripe_service
    @stripe_service ||= StripeService.new(customer_id: @customer_id)
  end
end
