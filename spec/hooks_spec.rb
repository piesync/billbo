require 'spec_helper'

describe Hooks do
  include Rack::Test::Methods

  def app
    Hooks
  end

  let(:invoice) {{
    id: '1',
    customer: '10'
  }}

  let(:stripe_invoice) { Stripe::Invoice.construct_from(invoice) }

  let(:internal_invoice) { Invoice.new }

  let(:vat_subscription_service) { mock }

  before do
    app.any_instance.stubs(:vat_subscription_service)
      .with(customer_id: '10').returns(vat_subscription_service)
  end

  describe 'post invoice created' do
    it 'finalizes the invoice' do
      vat_subscription_service.expects(:apply_vat).with do |i|
        i.to_h == self.invoice
      end.returns(stripe_invoice)

      post '/', json(type: 'invoice.created',
        data: { object: invoice })
      last_response.ok?.must_equal true
      last_response.body.must_be_empty
    end
  end

  describe 'post invoice payment succeeded' do
    it 'creates an invoice' do
      post '/', json(type: 'invoice.payment_succeeded',
        data: { object: invoice})
      last_response.ok?.must_equal true
      last_response.body.must_be_empty
    end
  end

  describe 'a stripe error occurs' do
    it 'responds with the error' do
      vat_subscription_service.expects(:apply_vat)
        .raises(Stripe::StripeError.new('not good'))

      post '/', json(type: 'invoice.created',
        data: { object: invoice })
      last_response.ok?.must_equal false
      last_response.body.must_equal '{"message":"not good"}'
    end
  end

  def json(object)
    MultiJson.dump(object)
  end
end
