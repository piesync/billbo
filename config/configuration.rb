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

    # Segment.io analytics handle
    attr_accessor :segmentio

    # Database handle
    attr_accessor :db

    # Amount of days until invoice is due
    attr_accessor :due_days

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
      @primary_country ||= SERVICE.primary_country
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
  end
end