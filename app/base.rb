class Base < Sinatra::Base
  disable :show_exceptions

  before do
    content_type 'application/json'
  end

  error Stripe::StripeError do |e|
    json(message: e.to_s)
  end

  error do |e|
    json(message: 'Something went wrong')
  end

  def json body = nil
    if body
      MultiJson.dump(body)
    else
      @json ||= MultiJson.load(request.body.read, symbolize_keys: true)
    end
  end

  protected

  def invoice_service(customer_id:)
    InvoiceService.new(customer_id: customer_id)
  end

  def vat_service
    VatService.new
  end
end
