require 'spec_helper'

describe InvoiceService do

  let(:metadata) {{
    country_code: 'NL',
    vat_registered: 'false',
    other: 'random'
  }}

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

  let(:service) { InvoiceService.new(customer_id: customer.id) }

  describe '#create_subscription' do
    it 'creates a subscription and an internal invoice, but does not finalize it yet' do
      VCR.use_cassette('create_subscription_and_invoice') do
        service.create_subscription(plan: plan.id)

        Invoice.count.must_equal 1
        invoice = Invoice.first
        invoice.added_vat?.must_equal true
        invoice.finalized?.must_equal false
        invoice.sequence_number.must_be_nil
      end
    end
  end

  describe '#ensure_vat' do
    it 'is idempotent' do
      VCR.use_cassette('apply_vat_idempotent') do
        Stripe::InvoiceItem.create \
          customer: customer.id,
          amount: 100,
          currency: 'usd'

        # Apply VAT on the upcoming invoice.
        stripe_invoice = Stripe::Invoice.create(customer: customer.id)
        invoice = service.ensure_vat(stripe_invoice_id: stripe_invoice.id)
        invoice.must_be_kind_of(Invoice)
        invoice.added_vat?.must_equal true

        # Apply again.
        service.ensure_vat(stripe_invoice_id: stripe_invoice.id)

        invoice = customer.invoices.first
        invoice.total.must_equal 121

        Invoice.count.must_equal 1
        invoice = Invoice.first
        invoice.added_vat?.must_equal true
      end
    end
  end

  describe '#process_payment' do

    it 'finalizes the invoice' do
      VCR.use_cassette('process_payment') do
        Stripe::InvoiceItem.create \
            customer: customer.id,
            amount: 100,
            currency: 'usd'

        stripe_invoice = Stripe::Invoice.create(customer: customer.id)

        invoice = service.process_payment(stripe_invoice_id: stripe_invoice.id)
        invoice.finalized?.must_equal true

        invoice.subtotal.must_equal 100
        invoice.discount_amount.must_equal 0
        invoice.subtotal_after_discount.must_equal 100
        invoice.vat_amount.must_equal 0
        invoice.vat_rate.must_equal 0
        invoice.total.must_equal 100

        stripe_invoice = Stripe::Invoice.retrieve(stripe_invoice.id)
        stripe_invoice.metadata.to_h.must_equal \
          number: "2014000001",
          subtotal: "100",
          discount_amount: "0",
          subtotal_after_discount: "100",
          vat_amount: "0",
          vat_rate: "0"
      end
    end

    describe 'when the total amount is zero' do
      it 'does not finalize the invoice' do
        VCR.use_cassette('process_payment_zero') do
          customer.subscriptions.create(plan: plan.id, trial_end: (Time.now.to_i + 1000))
          stripe_invoice = customer.invoices.first
          invoice = service.process_payment(stripe_invoice_id: stripe_invoice.id)
          invoice.finalized?.must_equal false
        end
      end
    end
  end

  describe '#process_refund' do

    it 'is an orphan refund' do
      VCR.use_cassette('process_refund_orphan') do
        proc { service.process_refund(stripe_invoice_id: 'xyz') }.must_raise InvoiceService::OrphanRefund
      end
    end

    describe 'when it is a real refund' do
      it 'creates a credit note' do
        VCR.use_cassette('process_refund') do
          Stripe::InvoiceItem.create \
            customer: customer.id,
            amount: 100,
            currency: 'usd'

        stripe_invoice = Stripe::Invoice.create(customer: customer.id)
        invoice = service.process_payment(stripe_invoice_id: stripe_invoice.id)

        credit_note = service.process_refund(stripe_invoice_id: stripe_invoice.id)
        credit_note.finalized?.must_equal true
        end
      end
    end
  end
end
