$db.create_table :invoices do
  primary_key :id

  Integer :year
  Integer :sequence_number
  String  :number, unique: true
  String  :stripe_id
  Boolean :added_vat
  Time    :finalized_at
  Time    :reserved_at
  Integer :total
  Integer :vat_amount
  Decimal :vat_rate
end unless $db.tables.include?(:invoices)
