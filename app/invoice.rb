class Invoice < Sequel::Model
  AlreadyFinalized = Class.new(StandardError)

  def self.find_or_create_by_stripe_id(stripe_id)
    transaction(isolation: :serializable,
                retry_on: [Sequel::SerializationFailure]) do
      find_or_create(stripe_id: stripe_id)
    end
  end

  def self.quarter(year, quarter)
    from = Date.new(year, (quarter-1)*3+1, 1)

    between(from, from+3.months)
  end

  dataset_module do
    def finalized
      exclude(finalized_at: nil)
    end

    def not_reserved
      where(reserved_at: nil)
    end

    def newest_first
      order(:finalized_at).reverse
    end

    def by_accounting_id(accounting_id)
      where(customer_accounting_id: accounting_id)
    end

    def finalized_before(before)
      where{finalized_at < before}
    end

    def finalized_after(after)
      where{finalized_at >= after}
    end

    def with_pdf_generated
      exclude(pdf_generated_at: nil)
    end

    def unprocessed(_)
      where(processed_at: nil)
    end
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

    self.class.with_next_sequence do |next_sequence|
      update_always(next_sequence)
    end

    self
  end

  def self.reserve!
    with_next_sequence do |next_sequence|
      create.tap do |invoice|
        invoice.update_always(next_sequence.merge(reserved_at: Time.now))
      end
    end
  end

  def process!
    update processed_at: Time.now if processed_at.nil?
    self
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

  def pdf_generated?
    !pdf_generated_at.nil?
  end

  def processed?
    !processed_at.nil?
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

  # Update record with given attributes regardless of the current
  # values thus overriding the sequel model logic which only saves
  # "changes".
  def update_always(attrs)
    attrs.keys.each{|k| modified!(k)}
    update(attrs)
  end

  def self.transaction(options = {}, &block)
    Configuration.db.transaction(options, &block)
  end

  def self.with_next_sequence(&block)
    transaction(isolation: :serializable,
                retry_on: [Sequel::UniqueConstraintViolation,
                           Sequel::SerializationFailure],
                num_retries: nil) do
      block.call(next_sequence)
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
      .exclude(number: nil)
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
