require "billbo/version"

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

  class << self

    attr_accessor :host

    private

    [:get, :post].each do |verb|
      define_method(verb) do |path, options = {}|
        raise 'Billbo host is not configured' unless Billbo.host

        response = RestClient.send(verb, "#{Billbo.host}#{path}", options)

        MultiJson.load(response.body, symbolize_keys: true)
      end
    end
  end
end
