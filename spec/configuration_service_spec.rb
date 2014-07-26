require 'spec_helper'

describe ConfigurationService do

  let(:service) { ConfigurationService.new }

  describe '#primary country' do
    it 'returns the primary country code' do
      VCR.use_cassette('primary_country') do
        service.primary_country.must_equal 'BE'
      end
    end
  end

  describe '#registered countries' do
    it 'returns an array of registered countries' do
      VCR.use_cassette('registered_countries') do
        service.registered_countries.must_equal(['BE'])
      end
    end
  end
end
