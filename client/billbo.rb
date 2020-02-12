require 'billbo/version'
require 'stripe'
require 'multi_json'
require 'uri'
require 'billbo/stripe_like'
require 'billbo/json_util'

module Billbo
  Invoice = Class.new(OpenStruct)

  class << self
    attr_accessor :host, :token

    # Fetches a preview breakdown of the costs of a subscription.
    #
    # plan             - Stripe plan ID.
    # country_code     - Country code of the customer (ISO 3166-1 alpha-2 standard)
    # vat_registered   - Whether the customer is VAT registered.
    #
    # Returns something like
    # {
    #    subtotal: 10,
    #    currency: 'eur',
    #    vat: 2.1,
    #    vat_rate: '21'
    # }
    def preview(options)
      [:plan, :country_code, :vat_registered].each do |key|
        raise ArgumentError, "#{key} not provided" if options[key].nil?
      end

      get("/preview/#{options[:plan]}", params: {
            country_code: options[:country_code],
            vat_registered: options[:vat_registered],
            quantity: options[:quantity]
          }.compact)
    end

    # validates a VAT number.
    #
    # number - the VAT number.
    #
    # Returns nil if the VAT number does not exist.
    def vat(number)
      get("/vat/#{number}")
      { number: number }
    rescue RestClient::ResourceNotFound
      nil
    end

    # gets details about a VAT number.
    #
    # number - the VAT number.
    # own_vat - own VAT number (to get a request identifier)
    #
    # Returns nil if the VAT number does not exist.
    def vat_details(number, own_vat = nil)
      get("/vat/#{number}/details", params: {
            own_vat: own_vat
          }.compact)
    rescue RestClient::ResourceNotFound
      nil
    end

    # Possibility to reserve an empty slot in the invoices
    # (for legacy invoice systems and manual invoicing).
    #
    # Returns something like
    # {
    #   year: 2014,
    #   sequence_number: 1,
    #   number: 2014.1,
    #   finalized_at: '2014-07-30 17:16:35 +0200',
    #   reserved_at: '2014-07-30 17:16:35 +0200'
    # }
    def reserve
      Invoice.new(post("/reserve", {}))
    end

    # Creates a new subscription with VAT.
    #
    # customer - ID of Stripe customer.
    # plan     - ID of plan to subscribe on.
    # any other stripe options.
    #
    # Returns the Stripe::Subscription if successful.
    def create_subscription(options)
      [:plan, :customer].each do |key|
        raise ArgumentError, "#{key} not provided" if options[key].nil?
      end

      body = StripeLike.request \
                          method: :post,
      url: "https://#{Billbo.host}/subscriptions",
      payload: options,
      content_type: 'application/x-www-form-urlencoded',
      user: 'X',
      password: Billbo.token

      Stripe::Subscription.construct_from(body)
    end

    # List invoices
    #
    # by_account_id     - customer account identifier
    # finalized_before  - finalized before given timestamp
    # finalized_after   - finalized after given timestamp
    # unprocessed       - not yet marked as processed
    #
    # Returns an array of {number: .., finalized_at: ..}.
    def invoices(options)
      get("/invoices", params: options).map do |invoice|
        Invoice.new(invoice)
      end
    end

    # Return PDF data of given invoice by number.
    def pdf(number)
      get("/invoices/#{number}.pdf")
    end

    # Mark an invoice as processed
    def process(number)
      Invoice.new(post("/invoices/#{number}/process", {}))
    rescue RestClient::ResourceNotFound
      nil
    end

    private

    [:get, :post, :put, :patch, :delete].each do |verb|
      define_method(verb) do |path, *args|
        raise 'Billbo host is not configured' unless Billbo.host

        response = RestClient.public_send(
          verb,
          "https://X:#{Billbo.token}@#{Billbo.host}#{path}",
          *args
        )

        if response.body.present? && response.headers[:content_type] == 'application/json'
          JsonUtil.parse_attributes(
            MultiJson.decode(response.body, symbolize_keys: true)
          )
        else
          response
        end
      end
    end
  end
end
