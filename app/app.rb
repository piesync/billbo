require 'template_view_model'

class App < Base
  TEMPLATE = Tilt.new(File.expand_path('../templates/default.html.slim', __FILE__))

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

  get '/invoices/:number.pdf' do
    invoice = Invoice.where(number: params[:number]).first

    halt 404 unless invoice && invoice.pdf_generated_at

    pdf = pdf_service.retrieve_pdf(invoice)

    content_type pdf.content_type
    body pdf.read
  end

  # Populates a template with all invoice data.
  # This should never be used to show to customers, it should
  # only be used to generate PDF's, as information on the invoice
  # could change between different calls.
  #
  # number - The invoice number.
  #
  # Returns the html and status 200 if successful
  get '/invoices/:number' do
    content_type 'text/html'

    invoice = Invoice.where(number: params[:number]).first

    if invoice.credit_note?
      credit_note = invoice
      invoice = Invoice.where(number: invoice.reference_number).first
    end

    halt 404 unless invoice

    stripe_invoice = Stripe::Invoice.retrieve(invoice.stripe_id)

    TEMPLATE.render(TemplateViewModel.new(
      invoice: invoice,
      stripe_invoice: stripe_invoice,
      stripe_coupon: stripe_invoice.discount && stripe_invoice.discount.coupon,
      credit_note: credit_note,
    ))
  end

  # List invoices
  #
  # by_account_id     - customer account identifier
  # finalized_before  - finalized before given timestamp
  # finalized_after   - finalized after given timestamp
  #
  # Returns a JSON array of {number: .., finalized_at: ..}.
  get '/invoices' do
    invoices = %w(by_account_id finalized_before finalized_after).reduce(
      Invoice.finalized.with_pdf_generated.newest_first
    ) do |scope,key|
      params.has_key?(key) ? scope.public_send(key, params[key]) : scope
    end

    json(
      invoices.
        map{|record| record.values.slice(:number, :finalized_at)}
    )
  end

  # Fetches a preview breakdown of the costs of a subscription.
  #
  # plan         - Stripe plan ID.
  # country_code - Country code of the customer (ISO 3166-1 alpha-2 standard)
  # vat_registered   - Whether the customer is vat registered (default: false).
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
      vat_registered: (params[:vat_registered] == 'true')

    json({
      subtotal: plan.amount,
      currency: plan.currency,
      vat: vat.amount,
      vat_rate: vat.rate
    })
  end

  # Checks if given VAT number is valid.
  #
  # vat_number  - VAT number to be validated
  #
  # Returns true or false
  get '/vat/:number' do
    if vat_service.valid?(vat_number: params[:number])
      status 200
    else
      status 404
    end
  end

  # returns extra info about the given vat_number
  #
  # vat_number  - VAT number to be validated
  # own_vat     - own VAT number to additionally get a request identifier
  #
  # Returns details or false/nil
  get '/vat/:number/details' do
    begin
      request = { vat_number: params[:number] }
      request.merge!(own_vat: params[:own_vat]) if params[:own_vat]

      vat_service.details(request) || status(404)

    rescue VatService::ViesDown
      status(504)
    end
  end

  get '/ping' do
    status 200
  end

  # Possibility to reserve an empty slot in the invoices
  # (for legacy invoice systems and manual invoicing).
  #
  # Returns 200 and
  # {
  #   year: 2014,
  #   sequence_number: 1,
  #   number: '2014.1'
  #   finalized_at: '2014-07-30 17:16:35 +0200',
  #   reserved_at: '2014-07-30 17:16:35 +0200'
  # }
  post '/reserve' do
    json(Invoice.reserve!)
  end
end
