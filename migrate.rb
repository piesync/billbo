require './environment'

$db.create_table :invoices do
  primary_key :id
  String :number
  Strimg :stripe_id
end
