require_relative 'spec_helper'

describe Invoice do
  let(:year) { Time.now.year }

  describe '#find_or_create' do
    it 'does not create duplicate invoices' do
      invoice1 = Invoice.find_or_create_by_stripe_id('1')
      Invoice.count.must_equal 1

      invoice2 = Invoice.find_or_create_by_stripe_id('1')
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
      invoice.number.must_equal "#{year}000001"
      invoice.finalized_at.must_be :>, Time.now - 10

      invoice = Invoice.new.finalize!
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 2
      invoice.number.must_equal "#{year}000002"
      invoice.finalized_at.must_be :>, Time.now - 10
    end

    it 'can not be finalized twice (idempotent)' do
      proc do
        invoice.finalize!.finalize!
      end.must_raise Invoice::AlreadyFinalized
    end

    it 'does not create two invoices with the same number' do
        Invoice.stubs(:next_sequence_number).returns(1).then.returns(1).then.returns(2)

        invoice1 = Invoice.new.finalize!
        invoice2 = Invoice.new.finalize!

        invoice1.number.must_equal "#{year}000001"
        invoice2.number.must_equal "#{year}000002"
    end

    it 'handles concurrency' do
      invoices = 25.times.map { Invoice.create }

      invoices.map do |invoice|
        Thread.new { invoice.finalize! }
      end.each(&:join)

      invoices.map(&:number).uniq.size.must_equal invoices.size
      invoices.map(&:year).uniq.size.must_equal 1
    end
  end

  describe '#reserve!' do
    let(:invoice) { Invoice.new }

    it 'reserves an empty slot for an invoice' do
      invoice1 = Invoice.reserve!
      Invoice.count.must_equal 1
      invoice1.year.must_equal year
      invoice1.sequence_number.must_equal 1
      invoice1.number.must_equal "#{year}000001"
      invoice1.finalized_at.must_be :>, Time.now - 10
      invoice1.reserved_at.must_be :>, Time.now - 10

      invoice2 = Invoice.reserve!
      invoice2.year.must_equal year
      invoice2.sequence_number.must_equal 2
      invoice2.number.must_equal "#{year}000002"
      invoice2.finalized_at.must_be :>, invoice1.finalized_at
      invoice2.reserved_at.must_be :>, invoice1.reserved_at

      invoice3 = Invoice.reserve!
      invoice3.year.must_equal year
      invoice3.sequence_number.must_equal 3
      invoice3.number.must_equal "#{year}000003"
      invoice3.finalized_at.must_be :>, invoice2.finalized_at
      invoice3.reserved_at.must_be :>, invoice2.reserved_at
    end

    it 'does not reserve two invoices with the same number' do
      Invoice.stubs(:next_sequence_number).returns(3).then.returns(3).then.returns(4)

      invoice1 = Invoice.reserve!
      invoice2 = Invoice.reserve!

      invoice1.number.must_equal "#{year}000003"
      invoice2.number.must_equal "#{year}000004"
    end

    it 'always computes the correct next sequence number' do
      # 2 invoices, finalized at the same time.
      time = Time.now
      Invoice.create(year: year, sequence_number: 1, number: "#{year}000002", finalized_at: time)
      Invoice.create(year: year, sequence_number: 2, number: "#{year}000001", finalized_at: time)
      Invoice.create.finalize!.number.must_equal "#{year}000003"
    end

    it 'finalizes an invoice and reserves an empty slot for an invoice' do
      invoice.finalize!
      Invoice.count.must_equal 1
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 1
      invoice.number.must_equal "#{year}000001"
      invoice.finalized_at.must_be :>, Time.now - 10

      invoice = Invoice.reserve!
      invoice.year.must_equal year
      invoice.sequence_number.must_equal 2
      invoice.number.must_equal "#{year}000002"
      invoice.finalized_at.must_be :>, Time.now - 10
      invoice.reserved_at.must_be :>, Time.now - 10
    end

  end

  describe 'process!' do
    let(:invoice) { Invoice.new }

    it 'sets the processed_at column to the current time if not set' do
      invoice.process!
      invoice.processed_at.must_be :>, Time.now - 10
    end

    it 'leaves the processed_at column to the original time if set' do
      past_processed_at = 10.days.ago
      invoice.update processed_at: past_processed_at
      invoice.process!
      invoice.processed_at.must_equal past_processed_at
    end
  end

end
