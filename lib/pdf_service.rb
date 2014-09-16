class PdfService

  def initalize(uploader: InvoiceUploader.new)
    @uploader = uploader
  end

  def generate_pdf(invoice)
    phantom = Shrimp::Phantom.new(
      "http://X:#{Configuration.api_token}@#{Configuration.host}/invoices/#{invoice.id}")
    phantom.to_pdf("#{invoice.id}.pdf")

    uploader.store!(File.open("#{invoice.id}.pdf"))
  end

  private

  attr_reader :uploader
end
