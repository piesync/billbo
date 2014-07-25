$db.create_table :invoices do
  primary_key :id

  Integer :year
  Integer :sequence_number
  String  :number
  String  :stripe_id
  Boolean :added_vat
  Time    :finalized_at
end unless $db.tables.include?(:invoices)
