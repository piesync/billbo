class PdfService

  def initialize(uploader: Configuration.uploader)
    @uploader = uploader
  end

  # Generates a PDF from an invoice and stores it (Locally or on Amazon S3).
  # Returns a File that refers to a temporary copy of the PDF.
  def generate_pdf(invoice)
    phantom = Shrimp::Phantom.new(
      "http://X:#{Configuration.api_token}@#{Configuration.host}/invoices/#{invoice.number}")
    phantom.to_pdf("tmp/#{invoice.number}.pdf")

    generated = File.open("tmp/#{invoice.number}.pdf")

    invoice.pdf_generated! if uploader.store!(file)

    file
  end

  def retrieve_pdf(invoice)
    uploader.retrieve_from_store!("#{invoice.number}.pdf")
    uploader.file
  end

  private

  attr_reader :uploader
end
