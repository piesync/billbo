require 'spec_helper'

describe VatService do

  let(:service) { VatService.new }

  describe '#calculate' do
    it 'calculates correct VAT amount' do
      VCR.use_cassette('calculate_vat') do
        example(100, 'US', true).amount.must_equal(0)
        example(100, 'US', false).amount.must_equal(0)

        example(100, 'FR', true).amount.must_equal(0)
        example(100, 'FR', false).amount.must_equal(21)

        example(100, 'BE', false).amount.must_equal(21)
        example(100, 'BE', true).amount.must_equal(21)
      end
    end
  end

  describe '#validate' do
    it 'validates the VAT number' do
      VCR.use_cassette('validate_vat') do
        service.valid?(vat_number: 'LU21416127').must_equal true
        service.valid?(vat_number: 'IE6388047V').must_equal true
        service.valid?(vat_number: 'LU21416128').must_equal false
      end
    end

    it 'validates the VAT number using the checksum' do
        Valvat::Lookup.stubs(:validate).returns(nil)
        service.valid?(vat_number: 'LU21416127').must_equal true
        service.valid?(vat_number: 'IE6388047V').must_equal true
        service.valid?(vat_number: 'LU21416128').must_equal false
    end
  end

  def example amount, country_code, company
    service.calculate(
      amount: amount, country_code: country_code, vat_registered: company)
  end
end
