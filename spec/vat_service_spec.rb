require_relative 'spec_helper'

describe VatService do

  let(:service) { VatService.new }

  describe '#calculate' do
    it 'calculates correct VAT amount' do
      example(100, 'US', true).amount.must_equal(0)
      example(100, 'US', false).amount.must_equal(0)

      example(100, 'FR', true).amount.must_equal(0)
      example(100, 'FR', false).amount.must_equal(20)

      example(100, 'BE', false).amount.must_equal(21)
      example(100, 'BE', true).amount.must_equal(21)

      # Rounded.
      example(2010, 'BE', true).amount.must_equal(422)
      example(2060, 'BE', true).amount.must_equal(433)

      # No country.
      example(1000, nil, true).amount.must_equal(0)
    end

    it 'works for the canary islands' do
      example(100, 'IC', true).amount.must_equal(0)
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

  describe '#details' do
    it 'returns details about the VAT number' do
      VCR.use_cassette('details_vat') do
        details = service.details(vat_number: 'LU21416127')

        details[:country_code].must_equal 'LU'
        details[:vat_number].must_equal '21416127'
        details[:name].must_equal 'EBAY EUROPE S.A R.L.'
        details[:address].must_equal "22, BOULEVARD ROYAL\nL-2449  LUXEMBOURG"
        details[:request_identifier].must_be_nil
      end
    end

    it 'returns details about the VAT number and a request identifier' do
      VCR.use_cassette('details_own_vat') do
        details = service.details(vat_number: 'LU21416127', own_vat: 'IE6388047V')

        details[:country_code].must_equal 'LU'
        details[:vat_number].must_equal '21416127'
        details[:name].must_equal 'EBAY EUROPE S.A R.L.'
        details[:address].must_equal "22, BOULEVARD ROYAL\nL-2449  LUXEMBOURG"
        details[:request_identifier].wont_be_nil
      end
    end

    describe 'the VIES service is down' do
      it 'raises an error' do
        Valvat.any_instance.stubs(:exists?).returns(nil)

        proc do
          service.details(vat_number: 'LU21416127')
        end.must_raise(VatService::ViesDown)
      end
    end
  end

  describe '#load_vies_data' do
    it 'loads vies data into an invoice' do
      VCR.use_cassette('load_vies_data') do
        invoice = Invoice.create(customer_vat_number: 'LU21416127')

        service.load_vies_data(invoice: invoice)

        invoice = invoice.reload

        invoice.vies_company_name.must_equal 'EBAY EUROPE S.A R.L.'
        invoice.vies_address.must_equal "22, BOULEVARD ROYAL\nL-2449  LUXEMBOURG"
        invoice.vies_request_identifier.wont_be_nil
      end
    end
  end

  def example amount, country_code, company
    service.calculate(
      amount: amount, country_code: country_code, vat_registered: company)
  end
end
