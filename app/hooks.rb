# Receives Webhooks from Stripe.
class Hooks < Base

  # All hooks are idempotent.
  # Returns 200 if successful
  post '/' do
    event  = Stripe::Event.construct_from(json)

    # Call method based on event type if it exists.
    method_name = event.type.gsub('.', '_').to_sym
    send(method_name, event) if respond_to?(method_name, true)

    # Send rumor event.
    rumor(method_name).on(event.data.object).mention(event: event).spread(async: false)

    status 200
  end

  private

  def customer_updated(event)
    if event.data.previous_attributes.to_hash.dig(:metadata, :country_code)
      # The country code has changed, we need to recalculate the tax percentage
      # and update it on the subscription
      StripeService.new(customer_id: event.data.object.id).update_vat_rate
    end
  end

  # Used to finalize invoices (assign number).
  def invoice_payment_succeeded(event)
    stripe_invoice = event.data.object

    invoice_service(
      customer_id: stripe_invoice.customer
    ).process_payment(
      stripe_event_id: event.id,
      stripe_invoice_id: stripe_invoice.id
    )
  end

  # Used to create credit notes. Use the ellipsis on the invoice page in Stripe to issue a credit note
  # Refunds that happen outside of credit notes are not handled.
  def credit_note_created(event)
    credit_note = event.data.object

    # we only handle full refunds for now
    if credit_note.invoice
      invoice_service(
        customer_id: credit_note.customer
      ).process_credit_note(
        stripe_event_id: event.id,
        stripe_credit_note_id: credit_note.id
      )
    end
  end
end
