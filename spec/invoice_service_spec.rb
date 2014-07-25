require 'spec_helper'

describe InvoiceService do

  let(:service) { InvoiceService.new }
  let(:year) { Time.now.year }

  describe '#find_or_create' do
    describe 'the stripe invoice does not exist yet' do
      it 'creates an invoice and assigns a number' do
        invoice = service.find_or_create
        invoice.year.must_equal year
        invoice.sequence_number.must_equal 1
        invoice.number.must_equal "#{year}.1"
        invoice.created_at.must_be :>, Time.now - 10

        invoice = service.find_or_create
        invoice.year.must_equal year
        invoice.sequence_number.must_equal 2
        invoice.number.must_equal "#{year}.2"
        invoice.created_at.must_be :>, Time.now - 10
      end
    end

    describe 'the stripe invoice already exists' do
      it 'does not create a duplicate invoice' do
        invoice1 = service.find_or_create(stripe_id: '1')
        Invoice.count.must_equal 1

        invoice2 = service.find_or_create(stripe_id: '1')
        invoice2.must_equal invoice1
        Invoice.count.must_equal 1
      end
    end
  end
end
