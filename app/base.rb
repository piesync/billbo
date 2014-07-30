class Base < Sinatra::Base
  disable :show_exceptions

  before do
    content_type 'application/json'
  end

  error Stripe::APIError do |e|
    stripe_error(e, type: 'api_error')
  end

  error Stripe::CardError do |e|
    status 402
    stripe_error(e, type: 'card_error', code: e.code, param: e.param)
  end

  error Stripe::InvalidRequestError do |e|
    status 400
    stripe_error(e, type: 'invalid_request_error', param: e.param)
  end

  error do |e|
    json(error: { message: 'Something went wrong' })
  end

  def json body = nil
    if body
      MultiJson.dump(body)
    else
      @json ||= MultiJson.load(request.body.read, symbolize_keys: true)
    end
  end

  protected

  def stripe_error(e, extra = {})
    json(error: { message: e.to_s }.merge(extra))
  end

  def invoice_service(customer_id:)
    InvoiceService.new(customer_id: customer_id)
  end

  def vat_service
    VatService.new
  end
end
