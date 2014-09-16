class InvoiceFileUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    'invoices'
  end
end
