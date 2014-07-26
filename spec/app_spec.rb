require 'spec_helper'

describe App do
  include Rack::Test::Methods

  def app
    App
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

  let(:subscription) {{
    customer: customer.id,
    plan: 'test'
  }}

  let(:metadata) {{
    country_code: 'NL',
    is_company: 'false',
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
        post '/subscriptions', json(subscription)

        last_response.ok?.must_equal true
        last_response.body.must_be_empty

        Invoice.count.must_equal 1
        invoice = Invoice.first
        invoice.added_vat?.must_equal true
        invoice.finalized_at.wont_be_nil
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

  def json(object)
    MultiJson.dump(object)
  end
end
