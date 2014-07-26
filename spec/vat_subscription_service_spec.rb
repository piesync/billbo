require 'spec_helper'

describe VatSubscriptionService do

  let(:metadata) {{
    country_code: 'NL',
    is_company: 'false',
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

  let(:service) { VatSubscriptionService.new(customer_id: customer.id) }

  describe '#apply_vat' do
    it 'finalizes an invoice by charging vat and snapshotting it' do
      VCR.use_cassette('apply_vat_success') do
        Stripe::InvoiceItem.create \
          customer: customer.id,
          amount: 100,
          currency: 'usd'

        # Apply VAT on the upcoming invoice.
        service.apply_vat(Stripe::Invoice.create(customer: customer.id))
          .must_be_kind_of(Stripe::Invoice)

        invoice = customer.invoices.first
        invoice.total.must_equal 121
        invoice.metadata.to_h.must_equal metadata
      end
    end
  end

  describe '#create_subscription' do
    it 'creates a subscription and adds VAT to the first invoice' do
      VCR.use_cassette('create_subscription_success') do
        invoice = service.create_subscription(plan: plan.id)
        invoice.must_be_kind_of(Stripe::Invoice)
        invoice.id.wont_be_nil

        invoices = customer.invoices
        invoices.to_a.size.must_equal 1
        invoice = invoices.first
        invoice.total.must_equal 1813
        invoice.lines.to_a.size.must_equal 2
        invoice.metadata.to_h.must_equal metadata

        upcoming = customer.upcoming_invoice
        # Upcoming does not have VAT yet, waiting to close invoice.
        upcoming.total.must_equal 1499
      end
    end
  end
end
