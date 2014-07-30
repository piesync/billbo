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
    it 'creates a subscription and an internal invoice' do
      VCR.use_cassette('create_subscription_and_invoice') do
        service.create_subscription(plan: plan.id)

        Invoice.count.must_equal 1
        invoice = Invoice.first
        invoice.added_vat?.must_equal true
        invoice.finalized?.must_equal true
        invoice.sequence_number.wont_be_nil
      end
    end
  end

  describe '#apply_vat' do
    it 'is idempotent' do
      VCR.use_cassette('apply_vat_idempotent') do
        Stripe::InvoiceItem.create \
          customer: customer.id,
          amount: 100,
          currency: 'usd'

        # Apply VAT on the upcoming invoice.
        stripe_invoice = Stripe::Invoice.create(customer: customer.id)
        invoice = service.apply_vat(stripe_invoice_id: stripe_invoice.id)
        invoice.must_be_kind_of(Invoice)
        invoice.added_vat?.must_equal true

        # Apply again.
        service.apply_vat(stripe_invoice_id: stripe_invoice.id)

        invoice = customer.invoices.first
        invoice.total.must_equal 121
        invoice.metadata.to_h.must_equal metadata.merge(
          vat_amount: '21', vat_rate: '21'
        )

        Invoice.count.must_equal 1
        Invoice.first.added_vat?.must_equal true
      end
    end
  end
end
