Configuration.db.create_table :invoices do
  primary_key :id

  Integer :year
  Integer :sequence_number
  String  :number, unique: true
  String  :stripe_id, unique: true
  Boolean :added_vat
  Time    :finalized_at
  Time    :reserved_at
  Integer :subtotal
  Integer :discount_amount
  Integer :subtotal_after_discount
  Integer :vat_amount
  Decimal :vat_rate
  Integer :total
  String  :currency
  String  :country_code
  Boolean :vat_registered
  String  :vat_number
  Boolean :credit_note, default: false
  String  :reference_number
  Time    :pdf_generated_at
  Decimal :exchange_rate_euro
  String  :vies_company_name
  String  :vies_address
  String  :vies_request_identifier
end unless Configuration.db.tables.include?(:invoices)
