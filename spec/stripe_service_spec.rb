require_relative 'spec_helper'

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

  let(:customer_invoices) do
    Stripe::Invoice.list(customer: customer.id, limit: 100)
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
        subscription = service.create_subscription(plan: plan.id, trial_from_plan: true)

        invoices = customer_invoices
        _(invoices.to_a.size).must_equal 1
        invoice = invoices.first

        _(invoice).must_be_kind_of(Stripe::Invoice)
        _(invoice.id).wont_be_nil

        _(invoice.total).must_equal 1814
        _(invoice.tax).must_equal 315
        _(invoice.lines.to_a.size).must_equal 1

        upcoming = Stripe::Invoice.upcoming(customer: customer.id)
        _(upcoming.total).must_equal 1814
        _(upcoming.tax).must_equal 315
        _(upcoming.lines.to_a.size).must_equal 1
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
          subscription = service.create_subscription(plan: plan.id, trial_from_plan: true)
          invoice = customer_invoices.first
          _(invoice.tax).must_equal 300
        end
      end
    end

    describe 'the plan has a trial period' do
      it 'creates a subscription but does not add VAT' do
        VCR.use_cassette('create_subscription_trial_success') do
          subscription = service.create_subscription(plan: trial_plan.id, trial_from_plan: true)

          invoices = customer_invoices
          _(invoices.to_a.size).must_equal 1
          invoice = invoices.first

          _(invoice).must_be_kind_of(Stripe::Invoice)
          _(invoice.id).wont_be_nil

          _(invoice.total).must_equal 0
          _(invoice.lines.to_a.size).must_equal 1

          upcoming = Stripe::Invoice.upcoming(customer: customer.id)
          _(upcoming.total).must_equal 1814
          _(upcoming.tax).must_equal 315
          _(upcoming.lines.to_a.size).must_equal 1
        end
      end
    end

    describe 'the subscription could not be created' do
      let(:card) { '4000000000000341' }

      it 'does not charge VAT' do
        VCR.use_cassette('create_subscription_fail') do
          _(proc do
            subscription = service.create_subscription(plan: plan.id, payment_behavior: 'error_if_incomplete')
          end).must_raise Stripe::CardError

          _(customer_invoices.to_a).must_be_empty
          _(Stripe::InvoiceItem.list(customer: customer.id, limit: 100)).must_be_empty
        end
      end
    end
  end

  describe "#update_vat_rate" do
    let(:updated_metadata) {{
      country_code: 'DE',
      vat_number: 'DE1234',
      vat_registered: 'false'
    }}

    let(:new_service) { StripeService.new(customer_id: customer.id) }

    it "updates the VAT rate on the subscription" do
      VCR.use_cassette('update_vat_rate') do
        subscription = service.create_subscription(plan: plan.id, trial_from_plan: true)
        old_tax_rate = subscription.default_tax_rates.first.percentage
        Stripe::Customer.update(customer.id, {metadata: updated_metadata})

        # Simulate a new service with uncached Stripe customer
        new_service.update_vat_rate
        new_tax_rate = Stripe::Subscription.retrieve(subscription.id).default_tax_rates.first.percentage
        _(new_tax_rate).wont_equal old_tax_rate
      end
    end
  end
end
