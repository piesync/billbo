require_relative 'spec_helper'

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

        _(invoice.vat_amount_eur > 0).must_equal true
        _(invoice.total_eur > 0).must_equal true
        _(invoice.exchange_rate_eur > 0).must_equal true
      end
    end

    describe 'to VIES or not to VIES' do
      describe 'EU' do
        let(:customer_country_code) { 'BE' }
        it 'loads VIES data' do
          VCR.use_cassette('vies_eu') do
            invoice = Invoice.create(vat_amount: 100, total: 1000, currency: 'usd', customer_country_code: customer_country_code, customer_vat_number: 'BE0849451764')

            VatService.any_instance.expects(:load_vies_data).with(invoice: invoice).once
            PdfService.any_instance.expects(:generate_pdf).with(invoice).once

            Job.new.perform_for([invoice])
          end
        end
      end

      describe 'UK' do
        let(:customer_country_code) { 'UK' }
        it 'does not load VIES data' do
          VCR.use_cassette('vies_uk') do
            invoice = Invoice.create(vat_amount: 100, total: 1000, currency: 'usd', customer_country_code: customer_country_code, customer_vat_number: 'GB123456789')

            VatService.any_instance.expects(:load_vies_data).with(invoice: invoice).never
            PdfService.any_instance.expects(:generate_pdf).with(invoice).once

            Job.new.perform_for([invoice])
          end
        end
      end

      describe 'US' do
        let(:customer_country_code) { 'US' }
        it 'does not load VIES data' do
          VCR.use_cassette('vies_us') do
            invoice = Invoice.create(vat_amount: 100, total: 1000, currency: 'usd', customer_country_code: customer_country_code)

            VatService.any_instance.expects(:load_vies_data).with(invoice: invoice).never
            PdfService.any_instance.expects(:generate_pdf).with(invoice).once

            Job.new.perform_for([invoice])
          end
        end
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
