class Configuration
  REQUIRED = [
    :api_token,
    :stripe_secret_key,
    :invoice_number_format,
    :database_url,
    :primary_country,
    :due_days
  ]

  SERVICE = ConfigurationService.new

  class << self
    # Handle to the Rack app
    attr_accessor :app

    # Billbo host
    attr_accessor :host

    # Security token used to access the API of the Billbo instance
    attr_accessor :api_token

    # Secret Stripe API key
    attr_accessor :stripe_secret_key

    # Segment.io write key (revenue analytics)
    attr_accessor :segmentio_write_key

    # Sentry endpoint to send errors to
    attr_accessor :sentry_dsn

    # String format for invoice numbers (printf), default: %{year}%<sequence>06d
    attr_accessor :invoice_number_format

    # SQL database url
    attr_accessor :database_url

    # Primary selling country
    attr_accessor :primary_country

    # Default currency of the seller
    attr_accessor :default_currency

    # Address of the seller
    attr_accessor :seller_address_line1
    attr_accessor :seller_address_line2

    # VAT number of the seller
    attr_accessor :seller_vat_number

    # Other information of the seller that the invoice must contain
    attr_accessor :seller_other_info

    # Bank name of the seller
    attr_accessor :seller_bank_name

    # BIC code of the seller's bank
    attr_accessor :seller_bic

    # IBAN number of the seller's bank account
    attr_accessor :seller_iban

    # Seller company name
    attr_accessor :seller_company_name

    # Seller logo
    attr_accessor :seller_logo_url

    # Seller email
    attr_accessor :seller_email

    # Segment.io analytics handle
    attr_accessor :segmentio

    # Database handle
    attr_accessor :db

    # Amount of days until invoice is due
    attr_accessor :due_days

    # S3 invoice storage
    attr_accessor :s3_key_id
    attr_accessor :s3_secret_key
    attr_accessor :s3_bucket
    attr_accessor :s3_region

    def due_days
      @due_days.to_i
    end

    def from_env(env = ENV)
      env.each do |key, value|
        method = "#{key.downcase}="
        send(method, value) if respond_to?(method)
      end

      self
    end

    def primary_country
      @primary_country ||= account.country
    end

    # TK extend to additional countries next to primary
    def registered_countries
      [primary_country]
    end

    def default_currency
      @default_currency ||= account.default_currency
    end

    def preload
      primary_country

      self
    end

    def valid?
      REQUIRED.none? { |field| send(field).nil? }
    end

    def sentry?
      !sentry_dsn.nil?
    end

    def segmentio?
      !segmentio_write_key.nil?
    end

    def s3?
      !s3_key_id.nil?
    end

    def uploader
      if s3?
        InvoiceCloudUploader.new
      else
        InvoiceFileUploader.new
      end
    end

    private

    def account
      @_account ||= SERVICE.account
    end
  end
end
