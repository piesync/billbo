require 'billbo/version'
require 'stripe'
require 'uri'
require 'billbo/stripe_like'

module Billbo

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
  def self.preview(options)
    [:plan, :country_code, :vat_registered].each do |key|
      raise ArgumentError, "#{key} not provided" unless options[key]
    end

    get("/preview/#{options[:plan]}", params: {
      country_code: options[:country_code],
      is_company: options[:vat_registered]
    })
  end

  # Fetches details about a VAT number.
  #
  # number - the VAT number.
  #
  # Returns nil if the VAT number does not exist.
  # TK return info about the vat number.
  def self.vat(number)
    get("/vat/#{number}")
    { number: number }
  rescue RestClient::ResourceNotFound
    nil
  end

  # Creates a new subscription with VAT.
  #
  # customer - ID of Stripe customer.
  # plan     - ID of plan to subscribe on.
  # any other stripe options.
  #
  # Returns the Stripe::Subscription if succesful.
  def self.create_subscription(options)
    [:plan, :customer].each do |key|
      raise ArgumentError, "#{key} not provided" unless options[key]
    end

    body = StripeLike.request \
      method: :post,
      url: "https://#{Billbo.host}/subscriptions",
      payload: URI.encode_www_form(options),
      content_type: 'application/x-www-form-urlencoded',
      user: 'X',
      password: Billbo.token

    Stripe::Subscription.construct_from(body)
  end

  class << self

    attr_accessor :host, :token

    private

    [:get, :post].each do |verb|
      define_method(verb) do |path, *args|
        raise 'Billbo host is not configured' unless Billbo.host

        response = RestClient.send(verb,
          "https://X:#{Billbo.token}@#{Billbo.host}#{path}", *args)

        MultiJson.load(response.body, symbolize_keys: true) if response.body && !response.body.empty?
      end
    end
  end
end
