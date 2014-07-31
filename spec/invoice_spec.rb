require 'spec_helper'

describe Invoice do
  let(:year) { Time.now.year }

  describe '#find_or_create' do
    it 'does not create duplicate invoices' do
      invoice1 = Invoice.find_or_create_from_stripe(stripe_id: '1')
      Invoice.count.must_equal 1

      invoice2 = Invoice.find_or_create_from_stripe(stripe_id: '1')
      invoice2.must_equal invoice1
      Invoice.count.must_equal 1
    end

    it 'accepts extra attributes' do
    end
  end

  describe '#finalize!' do
    let(:invoice) { Invoice.new }

    it 'assigns a number to the invoice and saves it' do
      invoice.finalize!
      Invoice.count.must_equal 1
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 1
      invoice.number.must_equal "#{year}.1"
      invoice.finalized_at.must_be :>, Time.now - 10

      invoice = Invoice.new.finalize!
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 2
      invoice.number.must_equal "#{year}.2"
      invoice.finalized_at.must_be :>, Time.now - 10
    end

    it 'can not be finalized twice (idempotent)' do
      proc do
        Invoice.new.finalize!.finalize!
      end.must_raise Invoice::AlreadyFinalized
    end

    it 'does not create two invoices with the same number' do
        Invoice.stubs(:next_sequence_number).returns(1).then.returns(1).then.returns(2)

        invoice1 = Invoice.new.finalize!
        invoice2 = Invoice.new.finalize!

        invoice1.number.must_equal "#{year}.1"
        invoice2.number.must_equal "#{year}.2"
    end
  end

  describe '#reserve!' do
    let(:invoice) { Invoice.new }

    it 'reserves an empty slot for an invoice' do
      invoice = Invoice.reserve!
      Invoice.count.must_equal 1
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 1
      invoice.number.must_equal "#{year}.1"
      invoice.finalized_at.must_be :>, Time.now - 10
      invoice.reserved_at.must_be :>, Time.now - 10

      invoice = Invoice.reserve!
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 2
      invoice.number.must_equal "#{year}.2"
      invoice.finalized_at.must_be :>, Time.now - 10
      invoice.reserved_at.must_be :>, Time.now - 10
    end

    it 'does not reserve two invoices with the same number' do
        Invoice.stubs(:next_sequence_number).returns(3).then.returns(3).then.returns(4)

        invoice1 = Invoice.reserve!
        invoice2 = Invoice.reserve!

        invoice1.number.must_equal "#{year}.3"
        invoice2.number.must_equal "#{year}.4"
    end

    it 'finalizes an invoice and reserves an empty slot for an invoice' do
      invoice.finalize!
      Invoice.count.must_equal 1
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 1
      invoice.number.must_equal "#{year}.1"
      invoice.finalized_at.must_be :>, Time.now - 10

      invoice = Invoice.reserve!
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 2
      invoice.number.must_equal "#{year}.2"
      invoice.finalized_at.must_be :>, Time.now - 10
      invoice.reserved_at.must_be :>, Time.now - 10
    end

  end

end
