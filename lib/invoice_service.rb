class InvoiceService

  def find_or_create(stripe_id: nil)
    # CHeck if an invoice exists already with that stripe id.
    invoice = Invoice.where(stripe_id: stripe_id)
      .limit(1).first if stripe_id

    invoice || create(stripe_id: stripe_id)
  end

  private

  def create(stripe_id: nil)
    # First reserve a slot in the table.
    invoice = Invoice.create(stripe_id: stripe_id)

    year = Time.now.year
    sequence_number = next_sequence_number(year)

    # Number is a formatted version of this.
    number = "#{year}.#{sequence_number}"

    # now update the invoice.
    invoice.update \
      year: year,
      sequence_number: sequence_number,
      number: number,
      created_at: Time.now

    invoice
  end

  def next_sequence_number(year)
    last_invoice = Invoice
      .where('number IS NOT NULL')
      .where(year: year)
      .order(:created_at)
      .limit(1)
      .first

    if last_invoice
      last_invoice.sequence_number + 1
    else
      1
    end
  end
end
