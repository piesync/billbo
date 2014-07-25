require 'spec_helper'

describe App do
  include Rack::Test::Methods

  def app
    App
  end

  let(:subscription) {{
    customer: '10',
    plan: 'test'
  }}

  let(:invoice) {{
    id: '1',
    customer: '10'
  }}

  let(:stripe_invoice) { Stripe::Invoice.construct_from(invoice) }

  let(:vat_subscription_service) { mock }
  let(:vat_service) { mock }

  before do
    app.any_instance.stubs(:vat_subscription_service)
      .with(customer_id: '10').returns(vat_subscription_service)
    app.any_instance.stubs(:vat_service).returns(vat_service)
  end

  describe 'post /invoice/created' do
    it 'finalizes the invoice' do
      vat_subscription_service.expects(:create_subscription).with do |s|
        s[:plan] == 'test'
      end.returns(stripe_invoice)

      post '/subscriptions', json(subscription)

      last_response.ok?.must_equal true
      last_response.body.must_be_empty

      Invoice.count.must_equal 1
      invoice = Invoice.first
      invoice.finalized_at.wont_be_nil
    end
  end

  describe 'get /vat/' do
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
