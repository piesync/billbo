require 'spec_helper'

describe AnalyticsChannel do
  include Rumor::Source

  let(:channel) { AnalyticsChannel.new }
  let(:customer_id) { '1' }
  let(:customer) do
    Stripe::Customer.construct_from \
      email: 'oss@piesync.com',
      metadata: {}
  end

  let(:charge) do
    { amount: 1000, customer: customer_id }
  end

  before do
    Stripe::Customer.stubs(:retrieve)
      .with(customer_id)
      .returns(customer)
  end

  describe 'charge_succeeded' do
    it 'tracks revenue changed' do
      $analytics.expects(:track).with \
        user_id: 'oss@piesync.com',
        event: 'revenue changed',
        properties: { revenue: 10.0 }

      channel.handle rumor(:charge_succeeded).on(charge)
    end
  end

  describe 'charge_refunded' do
    it 'tracks revenue changed' do
      $analytics.expects(:track).with \
        user_id: 'oss@piesync.com',
        event: 'revenue changed',
        properties: { revenue: -10.0 }

      channel.handle rumor(:charge_refunded).on(charge)
    end
  end
end
