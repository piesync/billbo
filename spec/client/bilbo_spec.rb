require 'spec_helper'

describe Billbo do

  let(:preview) {{
    subtotal: 10,
    currency: 'eur',
    vat: 2.1,
    vat_rate: '21'
  }}

  let(:subscription) {{
    id: "sub_4UdC1FzfwISacg",
    plan: "basic",
    object: "subscription",
    start: 1406653101,
    status: "active"
  }}

  let(:error) {{
    error: {
      message: "not good",
      type: "card_error",
      code: 1,
      param: "test"
    }
  }}

  describe '#preview' do
    it 'returns a preview price calculation' do
      stub_request(:get, "https://X:TOKEN@billbo.test/preview/basic")
        .with(query: { country_code: 'BE', is_company: 'false' })
        .to_return(body: MultiJson.dump(preview))

      _preview = Billbo.preview(plan: 'basic', country_code: 'BE',
        vat_registered: false)

      _preview.must_equal(preview)
    end
  end

  describe '#vat' do
    it 'returns the number itself if it exists' do
      stub_request(:get, "https://X:TOKEN@billbo.test/vat/BE123")
        .to_return(statsu: 200)

      Billbo.vat('BE123').must_equal number: 'BE123'
    end

    it 'returns nil if the vat number does not exist' do
      stub_request(:get, "https://X:TOKEN@billbo.test/vat/BE123")
        .to_return(status: 404)

      Billbo.vat('BE123').must_be_nil
    end
  end

  describe '#create_subscription' do
    it 'returns the created subscription' do
      stub_request(:post, "https://X:TOKEN@billbo.test/subscriptions")
        .with(body: { plan: 'basic', customer: 'x', other: 'things' })
        .to_return(body: MultiJson.dump(subscription))

      sub = Billbo.create_subscription(plan: 'basic',
        customer: 'x', other: 'things')

      sub.must_be_kind_of(Stripe::Subscription)
      sub.to_h.must_equal subscription
    end

    describe 'a Stripe error occurs' do
      it 'raises the error' do
        stub_request(:post, "https://X:TOKEN@billbo.test/subscriptions")
          .with(body: { plan: 'basic', customer: 'x', other: 'things' })
          .to_return(body: MultiJson.dump(error), status: 402)

        proc do
          sub = Billbo.create_subscription(plan: 'basic',
            customer: 'x', other: 'things')
        end.must_raise(Stripe::CardError)
      end
    end
  end
end
