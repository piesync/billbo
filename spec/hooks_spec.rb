require 'spec_helper'

describe Hooks do
  include Rack::Test::Methods

  def app
    Hooks
  end

  let(:metadata) {{
    country_code: 'NL',
    vat_registered: 'false',
    other: 'random'
  }}

  let(:customer) do
    Stripe::Customer.create \
      card: {
        number: '4242424242424242',
        exp_month: '12',
        exp_year: '30',
        cvc: '222'
      },
      metadata: metadata
  end

  let(:stripe_invoice) do
    Stripe::InvoiceItem.create \
      customer: customer.id,
      amount: 100,
      currency: 'usd'

    Stripe::Invoice.create(customer: customer.id)
  end

  describe 'any hook' do
    it 'spreads a rumor' do
      Rumor.expects(:spread).with do |rumor|
        rumor.event == :charge_succeeded &&
          rumor.subject == 1
      end

      post '/', json(type: 'charge.succeeded',
          data: { object: 1 })
    end
  end

  describe 'stubbed rumor' do
    before do
      Rumor.stubs(:spread)
    end

    describe 'post invoice created' do
      it 'adds VAT to the invoice' do
        VCR.use_cassette('hook_invoice_created') do
          post '/', json(type: 'invoice.created',
            data: { object: stripe_invoice })

          last_response.ok?.must_equal true
          last_response.body.must_be_empty

          Invoice.count.must_equal 1
          invoice = Invoice.first
          invoice.stripe_id.must_equal stripe_invoice.id
          invoice.sequence_number.must_be_nil
          invoice.added_vat?.must_equal true
          invoice.finalized_at.must_be_nil
        end
      end
    end

    describe 'post invoice payment succeeded' do
      it 'finalizes the invoice' do
        VCR.use_cassette('hook_invoice_payment_succeeded') do
          post '/', json(type: 'invoice.payment_succeeded',
            data: { object: stripe_invoice})

          last_response.ok?.must_equal true
          last_response.body.must_be_empty

          Invoice.count.must_equal 1
          invoice = Invoice.first
          invoice.sequence_number.must_equal 1
          invoice.finalized_at.wont_be_nil

          invoice.total.wont_be_nil
          invoice.vat_amount.wont_be_nil
          invoice.vat_rate.wont_be_nil
        end
      end
    end

    describe 'a stripe error occurs' do
      it 'responds with the error' do
        invoice_service = stub

        app.any_instance.stubs(:invoice_service)
          .with(customer_id: '10').returns(invoice_service)

        invoice_service.expects(:apply_vat)
          .raises(Stripe::CardError.new('not good', :test, 1))

        post '/', json(type: 'invoice.created',
          data: { object: { id: '1', customer: '10'} })

        last_response.ok?.must_equal false
        last_response.status.must_equal 402
        last_response.body.must_equal '{"error":{"message":"not good","type":"card_error","code":1,"param":"test"}}'
      end
    end
  end

  def json(object)
    MultiJson.dump(object)
  end
end
