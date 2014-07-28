class Base < Sinatra::Base
  include Rumor::Source

  disable :show_exceptions

  before do
    content_type 'application/json'
  end

  error Stripe::APIError do |e|
    stripe_error(e, type: 'api_error')
  end

  error Stripe::CardError do |e|
    stripe_error(e, type: 'card_error', code: e.code, param: e.param)
  end

  error Stripe::InvalidRequestError do |e|
    stripe_error(e, type: 'invalid_request_error', param: e.param)
  end

  error do |e|
    json(message: 'Something went wrong')
  end

  protected

  def json body = nil
    if body
      MultiJson.dump(body)
    else
      @json ||= MultiJson.load(request.body.read, symbolize_keys: true)
    end
  end

  def stripe_error(e, extra = {})
    json({message: e.to_s}.merge(extra))
  end

  def invoice_service(customer_id:)
    InvoiceService.new(customer_id: customer_id)
  end

  def vat_service
    VatService.new
  end
end
