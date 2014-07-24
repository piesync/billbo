class App < Base

  # Creates a new subscription with VAT.
  #
  # customer - ID of Stripe customer.
  # plan     - ID of plan to subscribe on.
  # any other stripe options.
  #
  # Returns 200 if succesful
  post '/subscriptions' do
    customer = json.delete(:customer)

    # Create subscription.
    invoice = vat_subscription_service(customer_id: customer)
      .create_subscription(json)

    # TK ONLY IF SUCCESFUL
    # If succesful, store the invoice.
    invoice_service.create(stripe_id: invoice.id)

    status 200
  end

  get '/ping' do
    status 200
  end
end