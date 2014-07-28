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
    rumor(:charge_succeeded).on(object).mention(event: event).spread

    status 200
  end

  private

  # This is used to:
  #   * Add VAT to the invoice.
  #   * Snapshot customer metadata in the invoice.
  def invoice_created(object)
    invoice = Stripe::Invoice.construct_from(object)

    invoice_service(customer_id: invoice.customer)
      .apply_vat(stripe_invoice_id: invoice.id)
  end

  # Used to finalize invoices (assign number).
  def invoice_payment_succeeded(object)
    Invoice.find_or_create_from_stripe(stripe_id: object[:id]).finalize!
  rescue Invoice::AlreadyFinalized
  end
end
