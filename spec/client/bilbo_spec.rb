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

  describe '#preview' do
    it 'returns a preview price calculation' do
      stub_request(:get, "http://billbo.test/preview/basic")
        .with(query: { country_code: 'BE', is_company: 'true' })
        .to_return(body: MultiJson.dump(preview))

      _preview = Billbo.preview(plan: 'basic', country_code: 'BE',
        vat_registered: true)

      _preview.must_equal(preview)
    end
  end

  describe '#create_subscription' do
    it 'returns the created subscription' do
      stub_request(:post, "http://billbo.test/subscriptions")
        .with(body: { plan: 'basic', customer: 'x', other: 'things' })
        .to_return(body: MultiJson.dump(subscription))

      sub = Billbo.create_subscription(plan: 'basic',
        customer: 'x', other: 'things')

      sub.must_be_kind_of(Stripe::Subscription)
      sub.to_h.must_equal subscription
    end
  end
end
