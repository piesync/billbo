require_relative 'spec_helper'

describe Invoice do
  let(:year) { Time.now.year }

  describe '#find_or_create' do
    it 'does not create duplicate invoices' do
      invoice1 = Invoice.find_or_create_by_stripe_id('1')
      _(Invoice.count).must_equal 1

      invoice2 = Invoice.find_or_create_by_stripe_id('1')
      _(invoice2).must_equal invoice1
      _(Invoice.count).must_equal 1
    end

    it 'accepts extra attributes' do
    end
  end

  describe '#finalize!' do
    let(:invoice) { Invoice.new }

    it 'assigns a number to the invoice and saves it' do
      invoice.finalize!
      _(Invoice.count).must_equal 1
      _(invoice.year).must_equal year
      _(invoice.sequence_number).must_equal 1
      _(invoice.number).must_equal "#{year}000001"
      _(invoice.finalized_at).must_be :>, Time.now - 10

      invoice = Invoice.new.finalize!
      _(invoice.year).must_equal year
      _(invoice.sequence_number).must_equal 2
      _(invoice.number).must_equal "#{year}000002"
      _(invoice.finalized_at).must_be :>, Time.now - 10
    end

    it 'can not be finalized twice (idempotent)' do
      _(proc do
        invoice.finalize!.finalize!
      end).must_raise Invoice::AlreadyFinalized
    end

    it 'does not create two invoices with the same number' do
        Invoice.stubs(:next_sequence_number).returns(1).then.returns(1).then.returns(2)

        invoice1 = Invoice.new.finalize!
        invoice2 = Invoice.new.finalize!

        _(invoice1.number).must_equal "#{year}000001"
        _(invoice2.number).must_equal "#{year}000002"
    end

    it 'handles concurrency' do
      invoices = 25.times.map { Invoice.create }

      invoices.map do |invoice|
        Thread.new { invoice.finalize! }
      end.each(&:join)

      _(invoices.map(&:number).uniq.size).must_equal invoices.size
      _(invoices.map(&:year).uniq.size).must_equal 1
    end
  end

  describe '#reserve!' do
    let(:invoice) { Invoice.new }

    it 'reserves an empty slot for an invoice' do
      invoice1 = Invoice.reserve!
      _(Invoice.count).must_equal 1
      _(invoice1.year).must_equal year
      _(invoice1.sequence_number).must_equal 1
      _(invoice1.number).must_equal "#{year}000001"
      _(invoice1.finalized_at).must_be :>, Time.now - 10
      _(invoice1.reserved_at).must_be :>, Time.now - 10

      invoice2 = Invoice.reserve!
      _(invoice2.year).must_equal year
      _(invoice2.sequence_number).must_equal 2
      _(invoice2.number).must_equal "#{year}000002"
      _(invoice2.finalized_at).must_be :>, invoice1.finalized_at
      _(invoice2.reserved_at).must_be :>, invoice1.reserved_at

      invoice3 = Invoice.reserve!
      _(invoice3.year).must_equal year
      _(invoice3.sequence_number).must_equal 3
      _(invoice3.number).must_equal "#{year}000003"
      _(invoice3.finalized_at).must_be :>, invoice2.finalized_at
      _(invoice3.reserved_at).must_be :>, invoice2.reserved_at
    end

    it 'does not reserve two invoices with the same number' do
      Invoice.stubs(:next_sequence_number).returns(3).then.returns(3).then.returns(4)

      invoice1 = Invoice.reserve!
      invoice2 = Invoice.reserve!

      _(invoice1.number).must_equal "#{year}000003"
      _(invoice2.number).must_equal "#{year}000004"
    end

    it 'always computes the correct next sequence number' do
      # 2 invoices, finalized at the same time.
      time = Time.now
      Invoice.create(year: year, sequence_number: 1, number: "#{year}000002", finalized_at: time)
      Invoice.create(year: year, sequence_number: 2, number: "#{year}000001", finalized_at: time)
      _(Invoice.create.finalize!.number).must_equal "#{year}000003"
    end

    it 'finalizes an invoice and reserves an empty slot for an invoice' do
      invoice.finalize!
      _(Invoice.count).must_equal 1
      _(invoice.year).must_equal year
      _(invoice.sequence_number).must_equal 1
      _(invoice.number).must_equal "#{year}000001"
      _(invoice.finalized_at).must_be :>, Time.now - 10

      invoice = Invoice.reserve!
      _(invoice.year).must_equal year
      _(invoice.sequence_number).must_equal 2
      _(invoice.number).must_equal "#{year}000002"
      _(invoice.finalized_at).must_be :>, Time.now - 10
      _(invoice.reserved_at).must_be :>, Time.now - 10
    end

  end

  describe 'process!' do
    let(:invoice) { Invoice.new }

    it 'sets the processed_at column to the current time if not set' do
      invoice.process!
      _(invoice.processed_at).must_be :>, Time.now - 10
    end

    it 'leaves the processed_at column to the original time if set' do
      past_processed_at = 10.days.ago
      invoice.update processed_at: past_processed_at
      invoice.process!
      _(invoice.processed_at).must_equal past_processed_at
    end
  end

end
