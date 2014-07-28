class Base < Sinatra::Base
  disable :show_exceptions

  error Stripe::StripeError do |e|
    json(message: e.to_s)
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
