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
    it 'loads euro amounts and generates a pdf' do
      VCR.use_cassette('job_exchange_rates') do
        invoice = Invoice.create(vat_amount: 100, total: 1000, currency: 'usd')

        VatService.any_instance.expects(:load_vies_data).with(invoice: invoice).never
        PdfService.any_instance.expects(:generate_pdf).with(invoice).once

        Job.new.perform_for([invoice])

        invoice = invoice.reload

        (invoice.vat_amount_eur > 0).must_equal true
        (invoice.total_eur > 0).must_equal true
        (invoice.exchange_rate_eur > 0).must_equal true
      end
    end

    describe 'a vat number is present' do
      it 'loads vies data, euro amounts and generates a pdf' do
        VCR.use_cassette('job_vat') do
          invoice = Invoice.create(vat_amount: 100, total: 1000, currency: 'usd', customer_vat_number: 'something')

          PdfService.any_instance.expects(:generate_pdf).with(invoice).once

          Job.new.perform_for([invoice])
        end
      end
    end

    describe 'called with a credit note' do
      it 'generates a pdf' do
        VCR.use_cassette('job_credit_note') do
          invoice = Invoice.create(vat_amount: 100, total: 1000, currency: 'usd')
          credit_note = Invoice.create(credit_note: true, reference_number: invoice.number)

          PdfService.any_instance.expects(:generate_pdf).with(credit_note).once

          Job.new.perform_for([credit_note])
        end
      end
    end
  end
end
