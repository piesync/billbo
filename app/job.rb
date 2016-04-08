# Gathers VIES data and generates PDFs.
class Job

  def perform
    # Iterate over all invoice we did not generate a PDF for yet.
    invoices = Invoice.where(pdf_generated_at: nil,reserved_at: nil)
      .where('finalized_at IS NOT NULL')

    perform_for(invoices)
  end

  def perform_for(invoices)
    # Update Exchange rates from ECB
    Money.default_bank.update_rates

    invoices.each do |invoice|
      perform_for_single(invoice)
    end
  end

  def perform_for_single(invoice)
    if !invoice.credit_note?
      # First load VIES data into the invoice.
      load_vies_data(invoice)

      # Calculate total and vat amount in euro.
      calculate_eur_amounts(invoice)
    end

    # Now generate an invoice.
    pdf = generate_pdf(invoice)

    # And mail it to the customer.
    mail_invoice(invoice, pdf)

  rescue VatService::ViesDown => e
    # Just wait until it's up again...

  rescue StandardError => e
    if Configuration.sentry?
      Raven.capture_exception(e, extra: {
        invoice: invoice.id
      })
    else
      raise e
    end
  end

  private

  def load_vies_data(invoice)
    vat_service.load_vies_data(invoice: invoice) if invoice.vat_registered?
  end

  def calculate_eur_amounts(invoice)
    invoice.update(
      exchange_rate_eur: Money.new(100, invoice.currency).exchange_to(:eur).to_f,
      vat_amount_eur: Money.new(invoice.vat_amount, invoice.currency).exchange_to(:eur).cents,
      total_eur: Money.new(invoice.total, invoice.currency).exchange_to(:eur).cents
    )
  end

  def generate_pdf(invoice)
    pdf_service.generate_pdf(invoice)
  end

  def mail_invoice(invoice, pdf)
    mail_service.mail(invoice, pdf)
  end

  def vat_service
    @vat_service ||= VatService.new
  end

  def pdf_service
    @pdf_service ||= PdfService.new
  end
end
