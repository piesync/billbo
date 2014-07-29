require 'spec_helper'

describe Billbo do

  let(:preview) {{
    subtotal: 10,
    currency: 'eur',
    vat: 2.1,
    vat_rate: '21'
  }}

  it 'works' do
    stub_request(:get, "http://billbo.test/preview/basic")
      .with(query: { country_code: 'BE', is_company: 'true' })
      .to_return(body: MultiJson.dump(preview))

    _preview = Billbo.preview(plan: 'basic', country_code: 'BE',
      vat_registered: true)

    _preview.must_equal(preview)
  end
end
