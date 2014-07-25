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
    before do
      vat_subscription_service.expects(:apply_vat).with do |i|
        i.to_h == self.invoice
      end.at_least_once.returns(stripe_invoice)
    end

    it 'adds VAT to the invoice' do
      post '/', json(type: 'invoice.created',
        data: { object: invoice })

      last_response.ok?.must_equal true
      last_response.body.must_be_empty

      Invoice.count.must_equal 1
      invoice = Invoice.first
      invoice.stripe_id.must_equal '1'
      invoice.sequence_number.must_be_nil
      invoice.added_vat?.must_equal true
      invoice.finalized_at.must_be_nil
    end

    it 'is idempotent' do
      post '/', json(type: 'invoice.created',
        data: { object: invoice })

      post '/', json(type: 'invoice.created',
        data: { object: invoice })

      Invoice.count.must_equal 1
      invoice = Invoice.first
      invoice.sequence_number.must_be_nil
      invoice.added_vat?.must_equal true
      invoice.finalized_at.must_be_nil
    end
  end

  describe 'post invoice payment succeeded' do
    it 'finalizes the invoice' do
      post '/', json(type: 'invoice.payment_succeeded',
        data: { object: invoice})

      last_response.ok?.must_equal true
      last_response.body.must_be_empty

      Invoice.count.must_equal 1
      invoice = Invoice.first
      invoice.sequence_number.must_equal 1
      invoice.finalized_at.wont_be_nil
    end

    it 'is idempotent' do
      post '/', json(type: 'invoice.payment_succeeded',
        data: { object: invoice})
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
