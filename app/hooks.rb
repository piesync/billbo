# Receives Webhooks from Stripe.
class Hooks < Base

  # This is used to:
  #   * Add VAT to the invoice.
  #   * Snapshot customer metadata in the invoice.
  #
  # Returns 200 if successful
  post '/invoice/created' do
    invoice = Stripe::Invoice.construct_from(json)

    vat_subscription_service(customer_id: invoice.customer)
      .finalize(invoice)

    status 200
  end

  # Used to create internal invoices.
  #
  # Returns 200 if successful
  post '/invoice/payment_succeeded' do
    invoice_service.create(stripe_id: json[:id])

    status 200
  end
end
