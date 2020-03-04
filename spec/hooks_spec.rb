require_relative 'spec_helper'

describe Hooks do
  include Rack::Test::Methods

  def app
    Hooks
  end

  let(:stripe_event_id) { 'xxx' }

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

  let(:customer_invoices) do
    Stripe::Invoice.list(customer: customer.id, limit: 1)
  end

  let(:stripe_invoice) do
    Stripe::InvoiceItem.create \
      customer: customer.id,
      amount: 100,
      currency: 'usd'

    Stripe::Invoice.create(customer: customer.id)
  end

  let(:plan) do
    begin
      Stripe::Plan.retrieve('test')
    rescue
      Stripe::Plan.create \
        id: 'test',
        name: 'Test Plan',
        amount: 1499,
        currency: 'usd',
        interval: 'month'
    end
  end

  describe 'any hook' do
    it 'spreads a rumor' do
      Rumor.expects(:spread).with do |rumor|
        rumor.event == :charge_succeeded &&
          rumor.subject == 1
      end

      post '/',
           json(
             id: stripe_event_id,
             type: 'charge.succeeded',
             data: {object: 1}
           )
    end
  end

  describe 'stubbed rumor' do
    before do
      Rumor.stubs(:spread)
    end

    describe 'post invoice payment succeeded' do
      it 'finalizes the invoice' do
        VCR.use_cassette('hook_invoice_payment_succeeded') do
          stripe_invoice.pay

          post '/',
               json(
                 id: stripe_event_id,
                 type: 'invoice.payment_succeeded',
                 data: { object: stripe_invoice}
               )

          _(last_response.ok?).must_equal true
          _(last_response.body).must_be_empty

          _(Invoice.count).must_equal 1
          invoice = Invoice.first
          _(invoice.sequence_number).must_equal 1
          _(invoice.finalized_at).wont_be_nil
          _(invoice.credit_note).must_equal false
        end
      end
    end

    describe 'post charge refunded' do
      it 'creates a credit note' do
        VCR.use_cassette('hook_charge_refunded') do
          customer.subscriptions.create(plan: plan.id)
          stripe_invoice = customer_invoices.first
          stripe_charge = Stripe::Charge.retrieve(stripe_invoice.charge)

          post '/',
               json(
                 id: stripe_event_id,
                 type: 'invoice.payment_succeeded',
                 data: {object: stripe_invoice}
               )

          refund = Stripe::Refund.create(charge: stripe_charge.id)

          stripe_charge = Stripe::Charge.retrieve(stripe_invoice.charge)

          post '/',
               json(
                 id: stripe_event_id,
                 type: 'charge.refunded',
                 data: {object: stripe_charge}
               )

          _(last_response.ok?).must_equal true
          _(last_response.body).must_be_empty

          _(Invoice.count).must_equal 2

          invoice = Invoice.order(:sequence_number).first
          _(invoice.sequence_number).must_equal 1
          _(invoice.finalized_at).wont_be_nil
          _(invoice.credit_note).must_equal false

          credit_note = Invoice.order(:sequence_number).last
          _(credit_note.sequence_number).must_equal 2
          _(credit_note.finalized_at).wont_be_nil
          _(credit_note.credit_note).must_equal true
          _(credit_note.reference_number).must_equal invoice.number
        end
      end
    end

    describe 'post charge refunded partial' do
      it 'does not create a credit note' do
        VCR.use_cassette('hook_charge_refunded_partial') do
          customer.subscriptions.create(plan: plan.id)
          stripe_invoice = customer_invoices.first
          stripe_charge = Stripe::Charge.retrieve(stripe_invoice.charge)

          post '/',
               json(
                 id: stripe_event_id,
                 type: 'invoice.payment_succeeded',
                 data: {object: stripe_invoice}
               )

          refund = Stripe::Refund.create(charge: stripe_charge.id, amount: 100)

          stripe_charge = Stripe::Charge.retrieve(stripe_invoice.charge)
          before_count = Invoice.count

          post '/',
               json(
                 id: stripe_event_id,
                 type: 'charge.refunded',
                 data: {object: stripe_charge}
               )

          _(last_response.ok?).must_equal true
          _(Invoice.count).must_equal before_count
        end
      end
    end

    describe 'a stripe error occurs' do
      it 'responds with the error' do
        invoice_service = stub

        app.any_instance.stubs(:invoice_service)
          .with(customer_id: '10').returns(invoice_service)

        invoice_service.expects(:process_payment)
          .raises(Stripe::CardError.new('not good', :test, code: 1))

        post '/',
             json(
               id: stripe_event_id,
               type: 'invoice.payment_succeeded',
               data: {object: {id: '1', customer: '10'}}
             )

        _(last_response.ok?).must_equal false
        _(last_response.status).must_equal 402
        _(last_response.body).must_equal '{"error":{"message":"not good","type":"card_error","code":1,"param":"test"}}'
      end
    end

    describe 'the customer does not have any metadata' do
      let(:metadata) { { other: 'random' } }

      it 'does nothing' do
        VCR.use_cassette('hook_invoice_created_no_meta') do
          stripe_invoice.pay

          post '/',
               json(
                 id: stripe_event_id,
                 type: 'invoice.payment_succeeded',
                 data: {object: Stripe::Invoice.retrieve(stripe_invoice.id)}
               )

          _(last_response.ok?).must_equal true
          invoice = Invoice.first
          _(invoice.number).wont_be_nil
        end
      end
    end
  end

  def json(object)
    MultiJson.dump(object)
  end
end
