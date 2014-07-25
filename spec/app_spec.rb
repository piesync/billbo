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

  before do
    app.any_instance.stubs(:vat_subscription_service)
      .with(customer_id: '10').returns(vat_subscription_service)
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

  def json(object)
    MultiJson.dump(object)
  end
end
