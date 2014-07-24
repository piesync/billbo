require 'spec_helper'

describe VatSubscriptionService do

  let(:plan) do
    Stripe::Plan.retrieve('test') || Stripe::Plan.create(\
      id: 'test',
      name: 'Test Plan',
      amount: 1499,
      currency: 'usd',
      interval: 'month'
    )
  end

  let(:customer) do
    Stripe::Customer.create \
      card: {
        number: '4242424242424242',
        exp_month: '12',
        exp_year: '30',
        cvc: '222'
      },
      metadata: {
        country_code: 'NL',
        is_company: false,
        other: 'random'
      }
  end

  let(:service) { VatSubscriptionService.new(customer_id: customer.id) }

  describe '#apply_vat' do
    describe 'no invoice is given (upcoming)' do
      it 'adds a VAT invoice item' do
        VCR.use_cassette('apply_vat_success') do
          service.charge_vat_of(100)

          invoices = customer.invoices
          invoices.to_a.size.must_equal 0

          upcoming = customer.upcoming_invoice
          upcoming.total.must_equal 21
          upcoming.lines.to_a.size.must_equal 1
          upcoming.lines.first.amount.must_equal 21
        end
      end
    end

    describe 'an invoice is given' do
      # TK todo
    end
  end

  describe '#create_subscription' do
    it 'creates a subscription and adds VAT to the first invoice' do
      VCR.use_cassette('create_subscription_success') do
        service.create_subscription(plan: plan.id)

        invoices = customer.invoices
        invoices.to_a.size.must_equal 1
        invoice = invoices.first
        invoice.total.must_equal 1813
        invoice.lines.to_a.size.must_equal 2
        invoice.metadata.to_h.must_equal \
          country_code: 'NL',
          is_company: 'false',
          other: 'random'

        upcoming = customer.upcoming_invoice
        # Upcoming does not have VAT yet, waiting to close invoice.
        upcoming.total.must_equal 1499
      end
    end
  end
end
