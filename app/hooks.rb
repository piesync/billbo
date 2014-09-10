# Receives Webhooks from Stripe.
class Hooks < Base

  # All hooks are idempotent.
  # Returns 200 if successful
  post '/' do
    event  = Stripe::Event.construct_from(json)
    object = event.data.object

    # Call method based on event type if it exists.
    method_name = event.type.gsub('.', '_').to_sym
    send(method_name, object) if respond_to?(method_name, true)

    # Send rumor event.
    rumor(method_name).on(object).mention(event: event).spread

    status 200
  end

  private

  # This is used to:
  #   * Add VAT to the invoice.
  #   * Snapshot customer metadata in the invoice.
  def invoice_created(object)
    stripe_invoice = Stripe::Invoice.construct_from(object)

    invoice_service(customer_id: stripe_invoice.customer)
      .ensure_vat(stripe_invoice_id: stripe_invoice.id)
  end

  # Used to finalize invoices (assign number).
  def invoice_payment_succeeded(object)
    stripe_invoice = Stripe::Invoice.construct_from(object)

    invoice_service(customer_id: stripe_invoice.customer)
      .process_payment(stripe_invoice_id: stripe_invoice.id)
  end

  # Used to handle refunds and create credit notes.
  def charge_refunded(object)
    stripe_charge = Stripe::Charge.construct_from(object)

    # we only handle full refunds for now
    if stripe_charge.refunded
      invoice_service(customer_id: stripe_charge.customer)
        .process_refund(stripe_invoice_id: stripe_charge.invoice)
    end

  end
end
