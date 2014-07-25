# Receives Webhooks from Stripe.
class Hooks < Base

  # All hooks are idempotent.
  # Returns 200 if successful
  post '/' do
    event  = Stripe::Event.construct_from(json)
    object = event.data.object

    case event.type
    when 'invoice.created'; invoice_created(object)
    when 'invoice.payment_succeeded'; invoice_payment_succeeded(object)
    end

    status 200
  end

  private

  # This is used to:
  #   * Add VAT to the invoice.
  #   * Snapshot customer metadata in the invoice.
  def invoice_created(object)
    invoice = Stripe::Invoice.construct_from(object)

    vat_subscription_service(customer_id: invoice.customer)
      .apply_vat(invoice)
  end

  # Used to create internal invoices.
  def invoice_payment_succeeded(object)
    invoice_service.find_or_create(stripe_id: object[:id])
  end
end
