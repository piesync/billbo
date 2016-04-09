require 'spec_helper'

describe Job do

  describe '#perform' do
    it 'calls perform for for all missing pdf invoices' do
      invoices = 5.times.map { Invoice.new.finalize! }
      Invoice.create

      job = Job.new

      job.expects(:perform_for).once.with do |invoices|
        invoices.to_a.size == 5
      end

      job.perform

      invoices.take(3).each(&:pdf_generated!)

      job.expects(:perform_for).once.with do |invoices|
        invoices.to_a.size == 2
      end

      job.perform
    end
  end

  describe '#perform_for' do
    before do
      path = File.expand_path('../test.pdf', __FILE__)

      PdfService
        .any_instance
        .expects(:generate_pdf)
        .with(invoice)
        .once
        .returns(File.open(path))

      MailService
        .any_instance
        .expects(:mail)
        .with(invoice, path)
        .once
    end

    let(:invoice) do
      Invoice.create(
        vat_amount: 100,
        total: 1000,
        currency: 'usd',
        customer_email: 'john.doe@customer.com'
      )
    end

    it 'loads euro amounts and generates a pdf' do
      VCR.use_cassette('job_exchange_rates') do
        VatService.any_instance.expects(:load_vies_data).never

        Job.new.perform_for([invoice])

        invoice.reload

        (invoice.vat_amount_eur > 0).must_equal true
        (invoice.total_eur > 0).must_equal true
        (invoice.exchange_rate_eur > 0).must_equal true
      end
    end

    describe 'a vat number is present' do
      let(:invoice) do
        Invoice.create(
          vat_amount: 100,
          total: 1000,
          currency: 'usd',
          customer_vat_number: 'LU21416127',
          customer_email: 'john.doe@customer.com'
        )
      end

      it 'loads vies data, euro amounts and generates a pdf' do
        VCR.use_cassette('job_vat') do
          Job.new.perform_for([invoice])

          invoice.reload

          invoice.vies_company_name.must_equal 'EBAY EUROPE S.A R.L.'
          invoice.vies_address.must_equal "22, BOULEVARD ROYAL\nL-2449  LUXEMBOURG"
          invoice.vies_request_identifier.wont_be_nil
        end
      end
    end

    describe 'called with a credit note' do
      let(:original) do
        Invoice.create(
          vat_amount: 100,
          total: 1000,
          currency: 'usd'
        )
      end

      let(:invoice) do
        Invoice.create(
          credit_note: true,
          reference_number: original.number,
          customer_email: 'john.doe@customer.com'
        )
      end

      it 'generates a pdf' do
        VCR.use_cassette('job_credit_note') do
          VatService.any_instance.expects(:load_vies_data).never
          Job.new.perform_for([invoice])
        end
      end
    end
  end
end
