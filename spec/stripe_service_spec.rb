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

  describe '#apply_vat' do
    it 'finalizes an invoice by charging vat and snapshotting it' do
      VCR.use_cassette('apply_vat_success') do
        Stripe::InvoiceItem.create \
          customer: customer.id,
          amount: 100,
          currency: 'usd'

        # Apply VAT on the upcoming invoice.
        service.apply_vat(invoice_id: stripe_invoice.id)
          .must_be_kind_of(Stripe::Invoice)

        invoice = customer.invoices.first
        invoice.total.must_equal 121

        invoice.lines.to_a.find { |l| l.description =~ /VAT/ }
          .description.must_equal 'VAT (21%)'
      end
    end

    describe 'the customer has a coupon' do
      it 'still calculates the total amount correctly' do
        VCR.use_cassette('apply_vat_coupon_success') do
          subscription, _ = service.create_subscription(
            plan: 'test', coupon: coupon.id)

          invoice = customer.invoices.first
          invoice.total.must_equal 1360

          Stripe::InvoiceItem.create \
            customer: customer.id,
            amount: 100,
            currency: 'usd'

          invoice = Stripe::Invoice.create(
            customer: customer.id, subscription: subscription.id)

          service.apply_vat(invoice_id: invoice.id)

          Stripe::Invoice.retrieve(invoice.id).total.must_equal 91
        end
      end
    end

    describe 'customer does not have to pay VAT' do
      let(:metadata) {{
        country_code: 'US',
        vat_registered: 'true',
        other: 'random'
      }}

      it 'does not add vat when amount is 0' do
        VCR.use_cassette('apply_vat_success_novat') do
          Stripe::InvoiceItem.create \
            customer: customer.id,
            amount: 100,
            currency: 'usd'

          # Apply VAT on the upcoming invoice.
          service.apply_vat(invoice_id: stripe_invoice.id)
            .must_be_kind_of(Stripe::Invoice)

          invoice = customer.invoices.first
          invoice.total.must_equal 100
          invoice.lines.to_a.size.must_equal 1
        end
      end
    end
  end

  describe '#create_subscription' do
    it 'creates a subscription and adds VAT to the first invoice' do
      VCR.use_cassette('create_subscription_success') do
        subscription, invoice = service.create_subscription(plan: plan.id)
        invoice.must_be_kind_of(Stripe::Invoice)
        invoice.id.wont_be_nil

        invoices = customer.invoices
        invoices.to_a.size.must_equal 1
        invoice = invoices.first
        invoice.total.must_equal 1814
        invoice.lines.to_a.size.must_equal 2

        upcoming = customer.upcoming_invoice
        # Upcoming does not have VAT yet, waiting to close invoice.
        upcoming.total.must_equal 1499
      end
    end

    describe 'the plan has a trial period' do
      it 'creates a subscription but does not add VAT' do
        VCR.use_cassette('create_subscription_trial_success') do
          subscription, invoice = service.create_subscription(plan: trial_plan.id)
          invoice.must_be_kind_of(Stripe::Invoice)
          invoice.id.wont_be_nil

          invoices = customer.invoices
          invoices.to_a.size.must_equal 1
          invoice = invoices.first
          invoice.total.must_equal 0
          invoice.lines.to_a.size.must_equal 1

          upcoming = customer.upcoming_invoice
          # Upcoming does not have VAT yet, waiting to close invoice.
          upcoming.total.must_equal 1499
        end
      end
    end

    describe 'the subscription overrides the trial period' do
      it 'creates a subscription but does not add VAT' do
        VCR.use_cassette('create_subscription_trial_sub_success') do
          subscription, invoice = service.create_subscription(
            plan: trial_plan.id, trial_end: Time.now.to_i + 1000)

          invoices = customer.invoices
          invoices.to_a.size.must_equal 1
          invoice = invoices.first
          invoice.total.must_equal 0
          invoice.lines.to_a.size.must_equal 1

          upcoming = customer.upcoming_invoice
          # Upcoming does not have VAT yet, waiting to close invoice.
          upcoming.total.must_equal 1499
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
