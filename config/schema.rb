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
  Boolean :credit_note, default: false
  String  :reference_number
end unless Configuration.db.tables.include?(:invoices)
