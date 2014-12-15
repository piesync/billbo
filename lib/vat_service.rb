class VatService
  ViesDown = Class.new(StandardError)
  VatCharge = Struct.new(:amount, :rate)

  # http://ec.europa.eu/taxation_customs/resources/documents/taxation/vat/how_vat_works/rates/vat_rates_en.pdf
  VAT_RATES = {
    'BE' => 21,
    'BG' => 20,
    'CZ' => 21,
    'DK' => 25,
    'DE' => 19,
    'EE' => 20,
    'EL' => 23,
    'ES' => 21,
    'FR' => 20,
    'HR' => 25,
    'IE' => 23,
    'IT' => 22,
    'CY' => 19,
    'LV' => 21,
    'LT' => 21,
    'LU' => 15,
    'HU' => 27,
    'MT' => 18,
    'NL' => 21,
    'AT' => 20,
    'PL' => 23,
    'PT' => 23,
    'RO' => 24,
    'SI' => 22,
    'SK' => 20,
    'FI' => 24,
    'SE' => 25,
    'UK' => 20
  }

  # Calculates VAT amount based on country and whether the customer
  # is a company or not.
  #
  # amount           - Base amount that is VAT taxable in cents (or not).
  # country_code     - ISO country code.
  # vat_registered   - true if a customer is vat registered
  #
  # Returns amount of VAT payable, in cents (rounded down).
  def calculate(amount:, country_code:, vat_registered:)
    rate = vat_rate(country_code: country_code,
      vat_registered: vat_registered)
    VatCharge.new((amount*rate/100.0).round, rate)
  end

  # Checks if given VAT number is valid.
  #
  # vat_number  - VAT number to be validated
  #
  # Returns true or false
  def valid?(vat_number:)
    vies_valid = Valvat::Lookup.validate(vat_number)
    if vies_valid.nil?
      Valvat.new(vat_number).valid_checksum?
    else
      vies_valid
    end
  end

  # returns extra info about the given vat_number
  #
  # vat_number  - VAT number to be validated
  # own_vat     - own VAT number to additionally get a request identifier
  #
  # Raises ViesDown if the VIES service is down.
  #
  # Returns details or false if the number does not exist.
  def details(vat_number:, own_vat: nil)
    details = if own_vat
      Valvat.new(vat_number).exists?(requester_vat: own_vat, raise_error: true)
    else
      Valvat.new(vat_number).exists?(detail: true)
    end

    raise ViesDown if details.nil?

    details
  end

  # Loads VIES data into the invoice model.
  #
  # Raises VatService::ViesDown if the VIES service is down.
  def load_vies_data(invoice: invoice)
    details = self.details(vat_number: invoice.customer_vat_number,
      own_vat: Configuration.seller_vat_number)

    invoice.update \
      vies_company_name: details[:name],
      vies_address: details[:address],
      vies_request_identifier: details[:request_identifier]
  end

  # Calculates VAT rate.
  #
  # country_code     - ISO country code.
  # vat_registered   - true if customer is vat registered
  #
  # Returns an integer (rate).
  def vat_rate(country_code:, vat_registered:)
    # VAT Rate is zero if country code is nil.
    return 0 if country_code.nil?

    # Companies pay VAT in the origin country when you are VAT registered there.
    # Individuals always need to pay the VAT rate set in their origin country.
    if registered?(country_code) || (eu?(country_code) && !vat_registered)
      VAT_RATES[country_code]

    # Companies in other EU countries don't need to pay VAT.
    # All non-EU customers don't need to pay VAT.
    else
      0
    end
  end

  private

  # Whether the seller is registered in the given country.
  def registered?(country_code)
    Configuration.registered_countries.include?(country_code)
  end

  def eu?(country_code)
    Valvat::Utils::EU_COUNTRIES.include?(country_code)
  end
end
