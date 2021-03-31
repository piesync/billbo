require_relative 'spec_helper'

describe VatService do

  let(:service) { VatService.new }

  describe '#calculate' do
    it 'calculates correct VAT amount' do
      _(example(100, 'US', true).amount).must_equal(0)
      _(example(100, 'US', false).amount).must_equal(0)

      _(example(100, 'FR', true).amount).must_equal(0)
      _(example(100, 'FR', false).amount).must_equal(20)

      _(example(100, 'BE', false).amount).must_equal(21)
      _(example(100, 'BE', true).amount).must_equal(21)

      # Rounded.
      _(example(2010, 'BE', true).amount).must_equal(422)
      _(example(2060, 'BE', true).amount).must_equal(433)

      # No country.
      _(example(1000, nil, true).amount).must_equal(0)
    end

    it 'works for the canary islands' do
      _(example(100, 'IC', true).amount).must_equal(0)
    end

    it 'works for the UK' do
      _(example(100, 'GB', false).amount).must_equal(20)
    end
  end

  describe '#validate' do
    it 'validates the VAT number' do
      VCR.use_cassette('validate_vat') do
        _(service.valid?(vat_number: 'IE6388047V')).must_equal true
        _(service.valid?(vat_number: 'LU21416128')).must_equal false
      end
    end

    it 'validates the VAT number using the checksum' do
      Valvat::Lookup.stubs(:validate).returns(nil)
      _(service.valid?(vat_number: 'IE6388047V')).must_equal true
      _(service.valid?(vat_number: 'LU21416128')).must_equal false
    end

    it 'uses the checksum if there is a communication error' do
      Valvat::Lookup.stubs(:validate).raises(Savon::Error)
      _(service.valid?(vat_number: 'IE6388047V')).must_equal true
    end

    it 'falls back to checksum for the UK' do
      VCR.use_cassette('validate_vat_gb') do
        _(service.valid?(vat_number: 'GB867935561')).must_equal true
      end
    end
  end

  describe '#details' do
    it 'returns details about the VAT number' do
      VCR.use_cassette('details_vat') do
        details = service.details(vat_number: 'BE0849451764')

        _(details[:country_code]).must_equal 'BE'
        _(details[:vat_number]).must_equal '0849451764'
        _(details[:name]).must_equal 'NV PieSync'
        _(details[:address]).must_equal "Notarisstraat 1\n9000 Gent"
        _(details[:request_identifier]).must_be_nil
      end
    end

    it 'returns details about the VAT number and a request identifier' do
      VCR.use_cassette('details_own_vat') do
        details = service.details(vat_number: 'IE6388047V', own_vat: 'BE0849451764')

        _(details[:country_code]).must_equal 'IE'
        _(details[:vat_number]).must_equal '6388047V'
        _(details[:name]).must_equal 'GOOGLE IRELAND LIMITED'
        _(details[:address]).must_equal "3RD FLOOR, GORDON HOUSE, BARROW STREET, DUBLIN 4"
        _(details[:request_identifier]).wont_be_nil
      end
    end

    describe 'the VIES service is down' do
      it 'raises an error' do
        Valvat.any_instance.stubs(:exists?).returns(nil)

        _(proc do
          service.details(vat_number: 'BE0849451764')
        end).must_raise(VatService::ViesDown)
      end
    end
  end

  describe '#load_vies_data' do
    it 'loads vies data into an invoice' do
      VCR.use_cassette('load_vies_data') do
        invoice = Invoice.create(customer_vat_number: 'BE0849451764')

        service.load_vies_data(invoice: invoice)

        invoice = invoice.reload

        _(invoice.vies_company_name).must_equal 'NV PieSync'
        _(invoice.vies_address).must_equal "Notarisstraat 1\n9000 Gent"
        _(invoice.vies_request_identifier).wont_be_nil
      end
    end
  end

  def example amount, country_code, company
    service.calculate(
      amount: amount, country_code: country_code, vat_registered: company)
  end
end
