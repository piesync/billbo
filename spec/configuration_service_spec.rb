require_relative 'spec_helper'

describe ConfigurationService do

  let(:service) { ConfigurationService.new }

  describe '#account' do
    it 'returns the Stripe account' do
      VCR.use_cassette('account') do
        _(service.account).must_be_kind_of Stripe::Account
      end
    end
  end
end
