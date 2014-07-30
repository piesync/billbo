class Invoice < Sequel::Model
  AlreadyFinalized = Class.new(StandardError)

  def self.find_or_create_from_stripe(stripe_id:, **attributes)
    attributes = attributes.merge(stripe_id: stripe_id)
    # Check if an invoice exists already with that stripe id.
    invoice = Invoice.first(stripe_id: stripe_id)

    invoice || create(attributes)
  end

  # TK what about finalizing 2 invoices at the same time?
  # TK only finalize when vat was added?
  def finalize!
    raise AlreadyFinalized if finalized?

    # now update the invoice.
    update self.class.next_sequence

    self
  end

  def self.reserve!
    reserved_info = next_sequence.merge!(reserved_at: Time.now)

    # now create the reserved slot.
    create reserved_info
  end

  def added_vat!
    update added_vat: true

    self
  end

  def added_vat?
    !!added_vat
  end

  def finalized?
    !finalized_at.nil?
  end

  private

  def self.next_sequence
    year = Time.now.year
    sequence_number = next_sequence_number(year)

    # Number is a formatted version of this.
    number = "#{year}.#{sequence_number}"
    {
      year: year,
      sequence_number: sequence_number,
      number: number,
      finalized_at: Time.now
    }
  end

  def self.next_sequence_number(year)
    last_invoice = Invoice
      .where('number IS NOT NULL')
      .where(year: year)
      .order(:finalized_at)
      .limit(1)
      .first

    if last_invoice
      last_invoice.sequence_number + 1
    else
      1
    end
  end
end
