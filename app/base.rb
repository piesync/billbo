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

  def vat_subscription_service(options)
    VatSubscriptionService.new(options)
  end

  def invoice_service
    InvoiceService.new
  end
end
