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

  it 'works' do
    VCR.use_cassette('pdf_test') do
      invoice_service.create_subscription(plan: plan.id)
      invoice = Invoice.first.finalize!

      p service.generate_pdf(invoice)
    end
  end
end
