class Invoice < Sequel::Model
  AlreadyFinalized = Class.new(StandardError)

  def self.find_or_create_from_stripe(stripe_id:, **attributes)
    # Wrapped in a safe transaction so we do not generate multiple invoices
    # associated with the same Stripe invoice.
    transaction do
      attributes = attributes.merge(stripe_id: stripe_id)
      # Check if an invoice exists already with that stripe id.
      invoice = Invoice.first(stripe_id: stripe_id)

      invoice || create(attributes)
    end
  end

  def self.quarter(year, quarter)
    from = Date.new(year, (quarter-1)*3+1, 1)

    between(from, from+3.months)
  end

  def_dataset_method(:finalized) do
    exclude(finalized_at: nil)
  end

  def_dataset_method(:not_reserved) do
    where(reserved_at: nil)
  end

  def_dataset_method(:newest_first) do
    order(:finalized_at).reverse
  end

  def_dataset_method(:by_account_id) do |account_id|
    where(customer_accounting_id: account_id)
  end

  def_dataset_method(:finalized_before) do |before|
    where{finalized_at < before}
  end

  def_dataset_method(:finalized_after) do |after|
    where{finalized_at >= after}
  end

  # Returns all finalized invoices from a given period.
  def self.between(from, to)
    finalized.
      not_reserved.
      finalized_after(from).
      finalized_before(to)
  end

  def finalize!
    raise AlreadyFinalized if finalized?

    # Wrapped in a safe transaction so we do not generate the same invoice number twice.
    transaction do
      # update the invoice.
      update self.class.next_sequence
    end

    self
  end

  def self.reserve!
    transaction do
      reserved_info = next_sequence.merge!(reserved_at: Time.now)
      # create the reserved slot.
      create reserved_info
    end
  end

  def added_vat!
    update added_vat: true

    self
  end

  def pdf_generated!
    update pdf_generated_at: Time.now

    self
  end

  def added_vat?
    !!added_vat
  end

  def finalized?
    !finalized_at.nil?
  end
  alias :paid? :finalized?

  def credit_note?
    !!credit_note
  end

  def due_at
    finalized_at + Configuration.due_days.days
  end

  def customer_vat_registered?
    !!customer_vat_registered
  end

  def discount?
    discount_amount && discount_amount != 0
  end

  def vat?
    vat_amount && vat_amount != 0
  end

  def eu?
    Valvat::Utils::EU_COUNTRIES.include?(customer_country_code)
  end

  def customer_name
    super || customer_email
  end

  def customer_company_name
    super || vies_company_name
  end

  def customer_address
    super || vies_address
  end

  def reference
    reference_number && Invoice.where(number: reference_number).first
  end

  private

  def transaction(&block)
    self.class.transaction(&block)
  rescue Sequel::Rollback
    # We refresh the model here because of a bug in Sequel.
    # Sequel marks the fields as non-dirty before executing the
    # actual update. When the transaction fails and we try
    # to allocate a new sequence number, the year does not change.
    # This results in the year not being saved.
    refresh
    retry
  end

  def self.transaction(&block)
    execute_transaction(&block)
  rescue Sequel::Rollback
    retry
  end

  def self.execute_transaction(&block)
    Configuration.db.transaction(isolation: :serializable, rollback: :reraise) do
      begin
        block.call
      rescue Sequel::UniqueConstraintViolation
        raise Sequel::Rollback
      end
    end
  end

  def self.next_sequence
    year = Time.now.year
    sequence_number = next_sequence_number(year)

    # Number is a formatted version of this.
    number = Configuration.invoice_number_format % { year: year, sequence: sequence_number }
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
      .order(Sequel.desc(:sequence_number))
      .limit(1)
      .first

    if last_invoice
      last_invoice.sequence_number + 1
    else
      1
    end
  end
end
