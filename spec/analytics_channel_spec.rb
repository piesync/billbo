require 'spec_helper'
require 'analytics_channel'

describe AnalyticsChannel do
  include Rumor::Source

  let(:analytics) { mock }
  let(:channel) { AnalyticsChannel.new(analytics) }

  let(:customer_id) { 'c1' }
  let(:customer) do
    Stripe::Customer.construct_from \
      email: 'oss@piesync.com',
      metadata: {}
  end

  let(:invoice_id) { 'i1' }
  let(:invoice) do
    Stripe::Invoice.construct_from \
      currency: 'usd',
      metadata: {
        vat_amount: '210',
        vat_rate: '21'
      }
  end

  let(:amount) { 1210 }
  let(:charge) do
    { amount: amount, customer: customer_id, invoice: invoice_id }
  end

  before do
    Stripe::Customer.stubs(:retrieve)
      .with(customer_id)
      .returns(customer)

    Stripe::Invoice.stubs(:retrieve)
      .with(invoice_id)
      .returns(invoice)
  end

  describe 'charge_succeeded' do
    it 'tracks revenue changed' do
      analytics.expects(:track).with \
        user_id: 'oss@piesync.com',
        event: 'revenue changed',
        properties: {
          revenue: 10.0,
          currency: 'usd',
          vat_amount: 2.1,
          vat_rate: '21',
          total: 12.1
        }

      channel.handle rumor(:charge_succeeded).on(charge)
    end

    describe 'vat amount not available' do
      let(:amount) { 1000 }
      let(:invoice) do
        Stripe::Invoice.construct_from \
          currency: 'usd',
          metadata: {}
      end

      it 'tracks revenue changed' do
        analytics.expects(:track).with \
          user_id: 'oss@piesync.com',
          event: 'revenue changed',
          properties: {
            revenue: 10.0,
            currency: 'usd',
            vat_amount: 0.0,
            vat_rate: '0',
            total: 10.0
          }

        channel.handle rumor(:charge_succeeded).on(charge)
      end
    end
  end

  describe 'charge_refunded' do
    it 'tracks revenue changed' do
      analytics.expects(:track).with \
        user_id: 'oss@piesync.com',
        event: 'revenue changed',
        properties: {
          revenue: -10.0,
          currency: 'usd',
          vat_amount: -2.1,
          vat_rate: '21',
          total: -12.1
        }

      channel.handle rumor(:charge_refunded).on(charge)
    end
  end
end
