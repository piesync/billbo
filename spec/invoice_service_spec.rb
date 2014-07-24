require 'spec_helper'

describe InvoiceService do

  let(:service) { InvoiceService.new }
  let(:year) { Time.now.year }

  describe '#create' do
    it 'creates an invoice and assigns a number' do
      invoice = service.create
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 1
      invoice.number.must_equal "#{year}.1"
      invoice.created_at.must_be :>, Time.now - 10

      invoice = service.create
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 2
      invoice.number.must_equal "#{year}.2"
      invoice.created_at.must_be :>, Time.now - 10
    end
  end
end
