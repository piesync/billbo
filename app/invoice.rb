class Invoice < Sequel::Model
  AlreadyFinalized = Class.new(StandardError)

  def self.find_or_create_from_stripe(attributes = {}, stripe_id:)
    attributes = attributes.merge(stripe_id: stripe_id)
    # Check if an invoice exists already with that stripe id.
    invoice = Invoice.where(stripe_id: stripe_id)
      .limit(1).first

    invoice || create(attributes)
  end

  # TK what about finalizing 2 invoices at the same time?
  def finalize
    raise AlreadyFinalized if finalized_at

    year = Time.now.year
    sequence_number = next_sequence_number(year)

    # Number is a formatted version of this.
    number = "#{year}.#{sequence_number}"

    # now update the invoice.
    update \
      year: year,
      sequence_number: sequence_number,
      number: number,
      finalized_at: Time.now

    self
  end

  private

  def next_sequence_number(year)
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
