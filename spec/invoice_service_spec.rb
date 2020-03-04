require_relative 'spec_helper'

describe InvoiceService do

  let(:stripe_event_id) { 'xxx' }

  let(:metadata) {{
    country_code: 'NL',
    vat_registered: 'false',
    vat_number: 'NL123',
    accounting_id: '10001',
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

  let(:customer_invoices) do
    Stripe::Invoice.list(customer: customer.id, limit: 1)
  end

  let(:coupon) do
    begin
      Stripe::Coupon.retrieve('25OFF')
    rescue
      Stripe::Coupon.create(
        percent_off: 25,
        duration: 'repeating',
        duration_in_months: 3,
        id: '25OFF'
      )
    end
  end

  let(:service) { InvoiceService.new(customer_id: customer.id) }

  describe '#process_payment' do
    describe 'with new invoice' do
      it 'finalizes the invoice' do
        VCR.use_cassette('process_payment_new') do
          service.create_subscription(plan: plan.id)

          invoice = service.process_payment(
            stripe_event_id: stripe_event_id,
            stripe_invoice_id: service.last_stripe_invoice.id
          )

          _(invoice.finalized?).must_equal true
          _(invoice.subtotal).must_equal 1499
          _(invoice.discount_amount).must_equal 0
          _(invoice.subtotal_after_discount).must_equal 1499
          _(invoice.vat_amount).must_equal 315
          _(invoice.vat_rate).must_equal 21
          _(invoice.total).must_equal 1814
          _(invoice.currency).must_equal 'usd'
          _(invoice.customer_country_code).must_equal 'NL'
          _(invoice.customer_vat_number).must_equal 'NL123'
          _(invoice.stripe_event_id).must_equal stripe_event_id
          _(invoice.stripe_customer_id).must_equal customer.id
          _(invoice.customer_accounting_id).must_equal '10001'
          _(invoice.customer_vat_registered).must_equal false
          _(invoice.card_brand).must_equal 'Visa'
          _(invoice.card_last4).must_equal '4242'
          _(invoice.card_country_code).must_equal 'US'
          _(invoice.interval).must_equal 'month'
          _(invoice.stripe_subscription_id).wont_be_nil
        end
      end

      describe 'when the plan is yearly' do
        let(:plan) do
          begin
            Stripe::Plan.retrieve('test_yearly')
          rescue
            Stripe::Plan.create \
              id: 'test_yearly',
              name: 'Test Yearly Plan',
              amount: 10000,
              currency: 'usd',
              interval: 'year'
          end
        end

        it 'finalizes the invoice' do
          VCR.use_cassette('process_payment_yearly') do
            service.create_subscription(plan: plan.id)

            invoice = service.process_payment(
              stripe_event_id: stripe_event_id,
              stripe_invoice_id: service.last_stripe_invoice.id
            )

            _(invoice.finalized?).must_equal true
            _(invoice.interval).must_equal 'year'
          end
        end
      end
    end

    describe 'with new invoice and discount' do
      it 'finalizes the invoice' do
        VCR.use_cassette('process_payment_new_discount') do
          service.create_subscription(plan: plan.id, coupon: coupon.id)

          invoice = service.process_payment(
            stripe_event_id: stripe_event_id,
            stripe_invoice_id: service.last_stripe_invoice.id
          )

          _(invoice.finalized?).must_equal true
          _(invoice.subtotal).must_equal 1499
          _(invoice.discount_amount).must_equal 375
          _(invoice.subtotal_after_discount).must_equal 1499-375
          _(invoice.vat_amount).must_equal 236
          _(invoice.vat_rate).must_equal 21
          _(invoice.total).must_equal 1360
          _(invoice.currency).must_equal 'usd'
          _(invoice.customer_country_code).must_equal 'NL'
          _(invoice.customer_vat_number).must_equal 'NL123'
          _(invoice.stripe_event_id).must_equal stripe_event_id
          _(invoice.stripe_customer_id).must_equal customer.id
          _(invoice.customer_accounting_id).must_equal '10001'
          _(invoice.customer_vat_registered).must_equal false
          _(invoice.card_brand).must_equal 'Visa'
          _(invoice.card_last4).must_equal '4242'
          _(invoice.card_country_code).must_equal 'US'
          _(invoice.interval).must_equal 'month'
        end
      end
    end

    describe 'when all the invoice lines are zero' do
      it 'does not create an invoice' do
        VCR.use_cassette('process_payment_zero_lines') do
          customer.subscriptions.create(plan: plan.id, trial_end: (Time.now.to_i + 1000))
          stripe_invoice = customer_invoices.first
          invoice = service.process_payment(
            stripe_event_id: stripe_event_id,
            stripe_invoice_id: stripe_invoice.id
          )

          _(invoice).must_be_nil
        end
      end
    end

    describe 'when the invoice total is zero' do
      it 'does create an invoice if some lines are not zero' do
        VCR.use_cassette('process_payment_zero') do
          Stripe::InvoiceItem.create(customer: customer.id, amount: -100, currency: 'usd')
          Stripe::InvoiceItem.create(customer: customer.id, amount: 100, currency: 'usd')
          stripe_invoice = Stripe::Invoice.create(customer: customer.id)
          stripe_invoice.pay

          stripe_invoice = customer_invoices.first
          invoice = service.process_payment(
            stripe_event_id: stripe_event_id,
            stripe_invoice_id: stripe_invoice.id
          )

          _(invoice).wont_be_nil
          _(invoice.total).must_equal 0
        end
      end
    end
  end

  describe '#process_refund' do
    it 'is an orphan refund' do
      VCR.use_cassette('process_refund_orphan') do
        _(proc do
          service.process_refund(
            stripe_event_id: stripe_event_id,
            stripe_invoice_id: 'xyz'
          )
        end).must_raise InvoiceService::OrphanRefund
      end
    end

    describe 'when it is a real refund' do
      it 'creates a credit note' do
        VCR.use_cassette('process_refund') do
          Stripe::InvoiceItem.create(
            customer: customer.id,
            amount: 100,
            currency: 'usd'
          )

          stripe_invoice = Stripe::Invoice.create(customer: customer.id)

          # Pay the invoice before processing the payment.
          stripe_invoice.pay

          service.process_payment(
            stripe_event_id: stripe_event_id,
            stripe_invoice_id: stripe_invoice.id
          )

          credit_note = service.process_refund(
            stripe_event_id: stripe_event_id,
            stripe_invoice_id: stripe_invoice.id
          )
          _(credit_note.finalized?).must_equal true
          _(credit_note.stripe_event_id).must_equal stripe_event_id
          _(credit_note.customer_accounting_id).must_equal metadata[:accounting_id]
        end
      end
    end
  end
end
