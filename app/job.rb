# Gathers VIES data and generates PDFs.
class Job

  def perform
    # Iterate over all invoice we did not generate a PDF for yet.
    # TK For now we do not generate credit notes automatically.
    Invoice.where(pdf_generated_at: nil,
      reserved_at: nil, credit_note: false).each do |invoice|
        perform_for(invoice)
    end
  end

  def perform_for(invoice)
    # First load VIES data into the invoice.
    vat_service.load_vies_data(invoice: invoice) if invoice.customer_vat_number

    # Calculate total and vat amount in euro.
    invoice.update \
      exchange_rate_eur: Money.new(100, invoice.currency).exchange_to(:eur).to_f,
      vat_amount_eur: Money.new(invoice.vat_amount, invoice.currency).exchange_to(:eur).cents,
      total_eur: Money.new(invoice.total, invoice.currency).exchange_to(:eur).cents

    # Now generate an invoice.
    pdf_service.generate_pdf(invoice)

  rescue VatService::ViesDown => e
    # Just wait until it's up again...
  rescue StandardError => e
    Raven.capture_exception(e) if Configuration.sentry?
  end

  private

  def vat_service
    @vat_service ||= VatService.new
  end

  def pdf_service
    @pdf_service ||= PdfService.new
  end
end
