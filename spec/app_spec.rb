require_relative 'spec_helper'

describe App do
  include Rack::Test::Methods

  def app
    App
  end

  before do
    Timecop.freeze(DateTime.parse('20/01/2016'))
  end

  after do
    Timecop.return
  end

  let(:vat_service) { mock }

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

  let(:yearly_plan) do
    begin
      Stripe::Plan.retrieve('test2')
    rescue
      Stripe::Plan.create \
        id: 'test2',
        name: 'Test2 Plan',
        amount: 2000,
        currency: 'usd',
        interval: 'year'
    end
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

  let(:subscription) {{
    customer: customer.id,
    plan: 'test'
  }}

  let(:metadata) {{
    name: 'John Doe',
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

  describe 'post /subscriptions' do
    it 'finalizes the invoice' do
      VCR.use_cassette('app_create_subscription') do
        post '/subscriptions', subscription

        last_response.ok?.must_equal true
        MultiJson.load(last_response.body)['customer'].must_equal customer.id
      end
    end
  end

  describe 'get /invoices/:number' do
    include Capybara::DSL

    before do
      page.driver.basic_authorize('', Configuration.api_token)
    end

    after do
      Capybara.reset_sessions!
    end

    let(:metadata) {{
      country_code: country_code,
      vat_registered: vat_registered,
      name: 'John Doe',
      vat_number: 'NL1234',
      address: 'Doestreet'
    }}

    let(:invoice_service) { InvoiceService.new(customer_id: customer.id) }

    describe 'subscription without VAT (export)' do
      let(:country_code) { 'US' }
      let(:vat_registered) { false }

      it 'generates an invoice without VAT' do
        VCR.use_cassette('invoice_template_sub_no_vat_export') do
          invoice_service.create_subscription(plan: plan.id)
          invoice_service.process_payment(
            stripe_invoice_id: customer.invoices.first.id)

          invoice = Invoice.first
          complete_invoice(invoice)
          number = invoice.number

          visit "/invoices/#{number}"
          page.save_screenshot('spec/visual/subscription_without_vat_export.png', :full => true)
        end
      end

      describe 'with proration' do
        it 'generates an invoice without VAT with multiple lines' do
          VCR.use_cassette('invoice_template_proration') do
            subscription, _ = invoice_service.create_subscription(plan: plan.id)

            subscription.plan = yearly_plan.id
            subscription.save

            id = customer.invoices.first.id

            invoice_service.process_payment(stripe_invoice_id: id)

            invoice = Invoice.last
            complete_invoice(invoice)
            number = invoice.number

            visit "/invoices/#{number}"
            page.save_screenshot('spec/visual/subscription_proration.png', :full => true)
          end
        end
      end
    end

    describe 'subscription without VAT (reverse)' do
      let(:country_code) { 'NL' }
      let(:vat_registered) { true }

      it 'generates an invoice without VAT' do
        VCR.use_cassette('invoice_template_sub_no_vat_reverse') do
          invoice_service.create_subscription(plan: plan.id)
          invoice_service.process_payment(
            stripe_invoice_id: customer.invoices.first.id)

          invoice = Invoice.first
          complete_invoice(invoice)
          number = invoice.number

          visit "/invoices/#{number}"
          page.save_screenshot('spec/visual/subscription_without_vat_reverse.png', :full => true)
        end
      end
    end

    describe 'subscription with VAT' do
      let(:country_code) { 'NL' }
      let(:vat_registered) { false }

      it 'generates an invoice with VAT' do
        VCR.use_cassette('invoice_template_sub_vat') do
          invoice_service.create_subscription(plan: plan.id)
          invoice_service.process_payment(
            stripe_invoice_id: customer.invoices.first.id)

          invoice = Invoice.first
          complete_invoice(invoice)
          number = invoice.number

          visit "/invoices/#{number}"
          page.save_screenshot('spec/visual/subscription_with_vat.png', :full => true)
        end
      end
    end

    describe 'subscription without VAT, with discount' do
      let(:country_code) { 'US' }
      let(:vat_registered) { false }

      it 'generates an invoice with VAT' do
        VCR.use_cassette('invoice_template_sub_no_vat_discount') do
          invoice_service.create_subscription(plan: plan.id, coupon: coupon.id)
          invoice_service.process_payment(
            stripe_invoice_id: customer.invoices.first.id)

          invoice = Invoice.first
          complete_invoice(invoice)
          number = invoice.number

          visit "/invoices/#{number}"
          page.save_screenshot('spec/visual/subscription_without_vat_with_discount.png', :full => true)
        end
      end
    end

    describe 'subscription with VAT, with discount' do
      let(:country_code) { 'NL' }
      let(:vat_registered) { false }

      it 'generates an invoice with VAT' do
        VCR.use_cassette('invoice_template_sub_vat_discount') do
          invoice_service.create_subscription(plan: plan.id, coupon: coupon.id)
          invoice_service.process_payment(
            stripe_invoice_id: customer.invoices.first.id)

          invoice = Invoice.first
          complete_invoice(invoice)
          number = invoice.number

          visit "/invoices/#{number}"
          page.save_screenshot('spec/visual/subscription_with_vat_with_discount.png', :full => true)
        end
      end
    end

    describe 'refund' do
      let(:country_code) { 'US' }
      let(:vat_registered) { false }

      it 'generates a credit note' do
        VCR.use_cassette('invoice_template_refund') do
          invoice_service.create_subscription(plan: plan.id)
          stripe_invoice = customer.invoices.first
          invoice_service.process_payment(
            stripe_invoice_id: stripe_invoice.id)

          Stripe::Charge.retrieve(stripe_invoice.charge).refund
          invoice_service.process_refund(
            stripe_invoice_id: stripe_invoice.id)

          invoice = Invoice.last
          complete_invoice(invoice)
          number = invoice.number

          visit "/invoices/#{number}"
          page.save_screenshot('spec/visual/refund.png', :full => true)
        end
      end
    end
  end

  describe 'get /invoices' do
    let(:now) { Time.now }
    let(:params) { {} }
    let(:accounting_id) { SecureRandom.hex }

    subject { get '/invoices', params }

    it 'responds with OK' do
      subject.status.must_equal 200
    end

    it 'responds with JSON' do
      subject.content_type.must_equal 'application/json'
    end

    describe 'ordering' do
      before do
        (0..99).to_a.shuffle.map do |i|
          Timecop.freeze(now + i.days) do
            Invoice.create.finalize!
          end
        end
      end

      it 'lists newest first' do
        result = JSON.parse(subject.body)
        result.first['finalized_at'].must_be :>, result.last['finalized_at']
      end
    end

    describe 'by account id' do
      let(:account_invoices) do
        10.times.map do |i|
          Invoice.create(customer_accounting_id: accounting_id).finalize!
        end
      end

      let(:other_invoices) do
        10.times.map do |i|
          Invoice.create.finalize!
        end
      end

      let(:params) { {by_accounting_id: accounting_id} }

      before do
        account_invoices
        other_invoices
      end

      it 'include all invoice for given account newest first' do
        JSON.parse(subject.body).map do |invoice|
          invoice["number"]
        end.to_set.must_equal account_invoices.map(&:number).to_set
      end
    end

    describe 'finalized before' do
      let(:invoices) do
        (0..9).map do |i|
          Timecop.freeze(now + i.days) do
            Invoice.create.finalize!
          end
        end
      end

      let(:params) { {finalized_before: (now + 4.5.days).iso8601} }
      before { invoices }

      it 'only returns the first invoices' do
        JSON.parse(subject.body).map do |invoice|
          invoice["number"]
        end.to_set.must_equal invoices[0..4].map(&:number).to_set
      end
    end

    describe 'finalized after' do
      let(:invoices) do
        (0..9).map do |i|
          Timecop.freeze(now + i.days) do
            Invoice.create.finalize!
          end
        end
      end

      let(:params) { {finalized_after: (now + 5.5.days).iso8601} }
      before { invoices }

      it 'only returns the last invoices' do
        JSON.parse(subject.body).map do |invoice|
          invoice["number"]
        end.to_set.must_equal invoices[6..-1].map(&:number).to_set
      end
    end

    describe 'combined filters' do
      let(:account_invoices) do
        (0..9).map do |i|
          Timecop.freeze(now + i.days) do
            Invoice.create(customer_accounting_id: accounting_id).finalize!
          end
        end
      end

      let(:other_invoices) do
        (0..9).map do |i|
          Timecop.freeze(now + i.days) do
            Invoice.create.finalize!
          end
        end
      end

      let(:params) do
        {
          by_accounting_id: accounting_id,
          finalized_after: (now + 5.5.days).iso8601,
          finalized_before: (now + 8.5.days).iso8601
        }
      end

      before do
        account_invoices
        other_invoices
      end

      it 'only returns the last invoices' do
        JSON.parse(subject.body).map do |invoice|
          invoice["number"]
        end.to_set.must_equal account_invoices[6..-2].map(&:number).to_set
      end
    end
  end

  describe 'get /preview' do
    it 'returns a price breakdown of a plan for a customer' do
      VCR.use_cassette('preview_success') do
        plan

        get '/preview/test', {
          country_code: 'BE',
          vat_registered: 'true'
        }

        last_response.ok?.must_equal true
        MultiJson.load(last_response.body, symbolize_keys: true).must_equal \
          subtotal: 1499,
          currency: 'usd',
          vat: 315,
          vat_rate: 21
      end
    end
  end

  describe 'get /vat/' do
    before do
      app.any_instance.stubs(:vat_service).returns(vat_service)
    end

    it 'validates a valid vat number' do
      vat_service.expects(:valid?).with(vat_number: '1').returns(true)

      get '/vat/1'
      last_response.ok?.must_equal true
      last_response.body.must_be_empty
    end

    it "doesn't find an invalid vat number" do
      vat_service.expects(:valid?).with(vat_number: '2').returns(false)

      get '/vat/2'
      last_response.ok?.must_equal false
      last_response.body.must_be_empty
    end
  end

  describe 'get /vat/details' do
    let(:details) {{
      country_code: 'IE',
      vat_number: '1',
      request_date: 'date',
      name: 'name',
      address: 'address'
    }}

    before do
      app.any_instance.stubs(:vat_service).returns(vat_service)
    end

    it 'returns details about a valid vat number' do
      vat_service.expects(:details).with(vat_number: '1').returns(MultiJson.dump(details))

      get '/vat/1/details'
      last_response.ok?.must_equal true

      MultiJson.load(last_response.body, symbolize_keys: true).must_equal details
    end

    it "doesn't find an invalid vat number" do
      vat_service.expects(:details).with(vat_number: '2').returns(false)

      get '/vat/2/details'
      last_response.ok?.must_equal false
      last_response.status.must_equal 404
      last_response.body.must_be_empty
    end

    it "returns 504 when VIES is down" do
      vat_service.expects(:details).with(vat_number: '1').raises(VatService::ViesDown)

      get '/vat/1/details'
      last_response.ok?.must_equal false
      last_response.status.must_equal 504
      last_response.body.must_be_empty
    end
  end

  describe 'post /reserve/' do
    it 'reserves a slot' do
      post '/reserve'
      last_response.ok?.must_equal true

      response = MultiJson.load(last_response.body, symbolize_keys: true)

      response[:year].wont_be_nil
      response[:sequence_number].wont_be_nil
      response[:number].wont_be_nil
      response[:finalized_at].wont_be_nil
      response[:reserved_at].wont_be_nil
    end

  end

  def json(object)
    MultiJson.dump(object)
  end

  def complete_invoice(invoice)
    invoice.update \
      vies_company_name: 'Ebay',
      vat_amount_eur: (invoice.vat_amount.to_i*0.75).round,
      total_eur: (invoice.total.to_i*0.75).round,
      currency: 'usd'
  end
end
