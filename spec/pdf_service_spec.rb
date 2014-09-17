require 'spec_helper'

describe PdfService do

  let(:service) { PdfService.new }
  let(:invoice_service) { InvoiceService.new(customer_id: customer.id) }

  let(:customer) do
    Stripe::Customer.create \
      card: {
        number: '4242424242424242',
        exp_month: '12',
        exp_year: '30',
        cvc: '222'
      }
  end

  let(:plan) do
    begin
      Stripe::Plan.retrieve('test')
    rescue
      Stripe::Plan.create \
        id: 'test',
        name: 'Test Plan',
        amount: 1499,
        currency: 'usd',
        interval: 'month'
    end
  end

  describe '#generate_pdf' do
    it 'generates a pdf representiation of an invoice and stores it' do
      VCR.use_cassette('pdf_generation') do
        invoice_service.create_subscription(plan: plan.id)
        invoice = Invoice.first.finalize!

        service.generate_pdf(invoice)

        invoice = invoice.reload
        invoice.pdf_generated_at.wont_be_nil

        uploader = Configuration.uploader
        uploader.retrieve_from_store!("#{invoice.number}.pdf")

        exists = File.exists?(
          File.expand_path("../../#{uploader.store_path}/#{uploader.filename}", __FILE__))

        exists.must_equal true
      end
    end

    describe '#generate_missing' do
      it 'generates all missing pdfs' do
        invoices = 5.times.map { Invoice.new.finalize! }

        service.expects(:generate_pdf)
          .with(instance_of(Invoice)).times(5)
        service.generate_missing

        invoices.each(&:pdf_generated!)

        service.expects(:generate_pdf).never
        service.generate_missing
      end
    end
  end
end
