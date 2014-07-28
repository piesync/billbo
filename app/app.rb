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
    subscription = invoice_service(customer_id: customer)
      .create_subscription(json)

    json(subscription)
  end

  get '/vat/:number' do
    if vat_service.valid?(vat_number: params[:number])
      status 200
    else
      status 404
    end
  end

  get '/ping' do
    status 200
  end
end
