require_relative '../spec_helper'

describe Billbo do

  let(:preview) {{
    subtotal: 10,
    currency: 'eur',
    vat: 2.1,
    vat_rate: '21'
  }}

  let(:reservation) {{
    year: 2014,
    sequence_number: 1,
    number: '2014.1',
    finalized_at: '2014-07-30 17:16:35 +0200',
    reserved_at: '2014-07-30 17:16:35 +0200'
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
      stub_app(:get, 'preview/basic', {query: {country_code: 'BE', vat_registered: 'false'}}, json: preview)

      Billbo.preview(
        plan: 'basic',
        country_code: 'BE',
        vat_registered: false
      ).must_equal preview
    end
  end

  describe '#reserve' do
    it 'reserves an empty invoice slot' do
      stub_app(:post, 'reserve', {}, json: reservation)

      Billbo.reserve.must_equal reservation
    end
  end

  describe '#vat' do
    it 'returns the number itself if it exists' do
      stub_app(:get, 'vat/BE123', {}, status: 200)

      Billbo.vat('BE123').must_equal number: 'BE123'
    end

    it 'returns nil if the vat number does not exist' do
      stub_app(:get, 'vat/BE123', {}, status: 404)

      Billbo.vat('BE123').must_be_nil
    end
  end

  describe '#vat/details' do
    let(:details) {{
      country_code: 'IE',
      vat_number: '1',
      request_date: 'date',
      name: 'name',
      address: 'address'
    }}

    it 'returns details about the number if it exists' do
      stub_app(:get, 'vat/BE123/details', {}, json: details)

      Billbo.vat_details('BE123').must_equal details
    end

    it 'returns nil if the vat number does not exist' do
      stub_app(:get, 'vat/BE123/details', {}, status: 404)

      Billbo.vat_details('BE123').must_be_nil
    end
  end

  describe '#create_subscription' do
    it 'returns the created subscription' do
      stub_app(:post, 'subscriptions', {body: {plan: 'basic', customer: 'x', other: 'things', metadata: {one: 'two'}}}, json: subscription)

      sub = Billbo.create_subscription(
        plan: 'basic',
        customer: 'x',
        other: 'things',
        metadata: {
          one: 'two'
        }
      )

      sub.must_be_kind_of(Stripe::Subscription)
      sub.to_h.must_equal subscription
    end

    describe 'a Stripe error occurs' do
      it 'raises the error' do
        stub_app(:post, 'subscriptions', {body: {plan: 'basic', customer: 'x', other: 'things'}}, status: 402, json: error)

        proc do
          Billbo.create_subscription(
            plan: 'basic',
            customer: 'x',
            other: 'things'
          )
        end.must_raise(Stripe::CardError)
      end
    end
  end

  describe '#invoices' do
    let(:account_id) { 'wilma' }
    let(:result) { ['fred', 'barney'] }

    before do
      stub_app(:get, 'invoices', {query: {by_account_id: account_id}}, json: result)
    end

    it 'returns result' do
      Billbo.invoices(by_account_id: account_id).
        must_equal(result)
    end
  end

  describe '#pdf' do
    let(:number) { 31415 }
    let(:data) { 'yabadabadoo!' }

    before do
      stub_app(:get, "invoices/#{number}.pdf", {}, body: data)
    end

    it 'returns data' do
      Billbo.pdf(number).
        must_equal(data)
    end
  end

  def stub_app(method, path, with, response)
    response = response.dup
    response[:status] ||= 200
    if json = response.delete(:json)
      response.merge!(
        headers: {content_type: 'application/json'},
        body: JSON.dump(json)
      )
    end

    stub_request(method, "https://X:TOKEN@billbo.test/#{path}")
      .with(with)
      .to_return(response)
  end
end
