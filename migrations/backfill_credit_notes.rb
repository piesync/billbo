# This migration fills in the columns for credit notes

# Before Stripe supported credit notes, only full refunds could be issued in order
# for a credit note to be created. This used the charge.refunded webhook.
# To support partial refunds however, credit_note.created is used instead.
# This migration script will fill in all existing credit note columns with the
# full values of the referred invoice.

require './config/environment'

execute = ARGV[0] == '--execute'


def safe(subject)
  begin
    yield
  rescue StandardError => e
    puts "Something went wrong with #{subject}!"
    puts e.message, *e.backtrace
  end
end

puts "--- Backfilling credit notes\n"

credit_notes = Invoice.not_reserved.where(credit_note: true).exclude(reference_number: nil)

credit_notes.each do |credit_note|
  safe(credit_note.number) do
    invoice = Invoice.find(number: credit_note.reference_number)

    raise "invoice with number #{credit_note.reference_number} does not exist" unless invoice

    attributes = Hash[
      %i(
        total vat_amount vat_rate subtotal discount_amount subtotal_after_discount currency
        exchange_rate_eur vat_amount_eur total_eur
        card_brand card_last4 card_country_code
      ).map{|field| [field, invoice.public_send(field)]}
    ]

    credit_note.update(attributes) if execute

    puts "Credit note #{credit_note.number}: #{attributes.inspect} #{execute ? '[updated]' : ''}"
  end
end

puts "--- all done"