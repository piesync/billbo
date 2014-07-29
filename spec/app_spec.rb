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
        MultiJson.load(last_response.body)['customer'].must_equal customer.id
      end
    end
  end

  describe 'get /preview' do
    it 'returns a price breakdown of a plan for a customer' do
      VCR.use_cassette('preview_success') do
        plan

        get '/preview/test', {
          country_code: 'BE',
          is_company: 'true'
        }

        last_response.ok?.must_equal true
        MultiJson.load(last_response.body, symbolize_keys: true).must_equal \
          subtotal: 1499,
          currency: 'usd',
          vat: 314,
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

  def json(object)
    MultiJson.dump(object)
  end
end
