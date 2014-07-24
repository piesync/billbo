class Base < Sinatra::Base

  def json
    @json ||= MultiJson.load(request.body.read, symbolize_keys: true)
  end

  protected

  def vat_subscription_service(options)
    VatSubscriptionService.new(options)
  end

  def invoice_service
    InvoiceService.new
  end
end
