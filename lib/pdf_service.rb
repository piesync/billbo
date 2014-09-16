class PdfService

  def initalize(uploader: InvoiceUploader.new)
    @uploader = uploader
  end

  def generate_pdf(invoice)
    phantom = Shrimp::Phantom.new(
      "http://X:#{Configuration.api_token}@#{Configuration.host}/invoices/#{invoice.id}")
    phantom.to_pdf("#{invoice.id}.pdf")

    Invoice.pdf_generated! if uploader.store!(File.open("#{invoice.id}.pdf"))
  end

  def generate_missing
    Invoice.where(pdf_generated_at: nil).each do |invoice|
      generate_pdf(invoice)
    end
  end

  private

  attr_reader :uploader
end
