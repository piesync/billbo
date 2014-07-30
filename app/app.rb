class App < Base

  # Creates a new subscription with VAT.
  #
  # customer - ID of Stripe customer.
  # plan     - ID of plan to subscribe on.
  # any other stripe options.
  #
  # Returns 200 if succesful
  post '/subscriptions' do
    customer = params.delete('customer')

    # Create subscription.
    subscription = invoice_service(customer_id: customer)
      .create_subscription(params)

    json(subscription)
  end

  # Fetches a preview breakdown of the costs of a subscription.
  #
  # plan         - Stripe plan ID.
  # country_code - Country code of the customer (ISO 3166-1 alpha-2 standard)
  # is_company   - Whether the customer is a company (default: false).
  #
  # Returns 200 and
  # {
  #    subtotal: 10,
  #    currency: 'eur',
  #    vat: 2.1,
  #    vat_rate: '21'
  # }
  get '/preview/:plan' do
    plan = Stripe::Plan.retrieve(params[:plan])

    vat = vat_service.calculate \
      amount: plan.amount,
      country_code: params[:country_code],
      is_company: (params[:is_company] == 'true')

    json({
      subtotal: plan.amount,
      currency: plan.currency,
      vat: vat.amount,
      vat_rate: vat.rate
    })
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
