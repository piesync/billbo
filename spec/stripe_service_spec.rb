require 'spec_helper'

describe StripeService do

  let(:metadata) {{
    country_code: 'NL',
    vat_registered: 'false',
    other: 'random'
  }}

  let(:trial_plan) do
    begin
      Stripe::Plan.retrieve('trial_plan')
    rescue
      Stripe::Plan.create \
        id: 'trial_plan',
        name: 'Trial Plan',
        amount: 1499,
        currency: 'usd',
        interval: 'month',
        trial_period_days: 10
    end
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

  let(:card) { '4242424242424242' }

  let(:customer) do
    Stripe::Customer.create \
      card: {
        number: card,
        exp_month: '12',
        exp_year: '30',
        cvc: '222'
      },
      metadata: metadata
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

  let(:stripe_invoice) { Stripe::Invoice.create(customer: customer.id) }

  let(:service) { StripeService.new(customer_id: customer.id) }

  describe '#create_subscription' do
    it 'creates a subscription and adds VAT to the first invoice' do
      VCR.use_cassette('create_subscription_success') do
        subscription = service.create_subscription(plan: plan.id)

        invoices = customer.invoices
        invoices.to_a.size.must_equal 1
        invoice = invoices.first

        invoice.must_be_kind_of(Stripe::Invoice)
        invoice.id.wont_be_nil

        invoice.total.must_equal 1814
        invoice.tax.must_equal 315
        invoice.lines.to_a.size.must_equal 1

        upcoming = customer.upcoming_invoice
        upcoming.total.must_equal 1814
        upcoming.tax.must_equal 315
        upcoming.lines.to_a.size.must_equal 1
      end
    end

    describe 'the customer has a VAT number' do
      let(:metadata) {{
        country_code: 'NL',
        vat_number: 'GB1234',
        vat_registered: 'false',
        other: 'random'
      }}

      it 'uses the VAT country code' do
        VCR.use_cassette('create_subscription_vat_success') do
          subscription = service.create_subscription(plan: plan.id)
          invoice = customer.invoices.first
          invoice.tax.must_equal 300
        end
      end
    end

    describe 'the plan has a trial period' do
      it 'creates a subscription but does not add VAT' do
        VCR.use_cassette('create_subscription_trial_success') do
          subscription = service.create_subscription(plan: trial_plan.id)

          invoices = customer.invoices
          invoices.to_a.size.must_equal 1
          invoice = invoices.first

          invoice.must_be_kind_of(Stripe::Invoice)
          invoice.id.wont_be_nil

          invoice.total.must_equal 0
          invoice.lines.to_a.size.must_equal 1

          upcoming = customer.upcoming_invoice
          upcoming.total.must_equal 1814
          upcoming.tax.must_equal 315
          upcoming.lines.to_a.size.must_equal 1
        end
      end
    end

    describe 'the subscription could not be created' do
      let(:card) { '4000000000000341' }

      it 'does not charge VAT' do
        VCR.use_cassette('create_subscription_fail') do
          proc do
            service.create_subscription(plan: plan.id)
          end.must_raise Stripe::CardError

          customer.invoices.to_a.must_be_empty
          Stripe::InvoiceItem.all(customer: customer.id).to_a.must_be_empty
        end
      end
    end
  end
end
