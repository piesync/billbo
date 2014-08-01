class VatService
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
  # amount       - Base amount that is VAT taxable in cents (or not).
  # country_code - ISO country code.
  # vat_registered   - true if a customer is vat registered
  #
  # Returns amount of VAT payable (rounded down).
  def calculate(amount:, country_code:, vat_registered:)
    rate = vat_rate(country_code, vat_registered)
    VatCharge.new(amount*rate/100, rate)
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
  # Returns details or false/nil
  def details(vat_number:, own_vat: nil)
    if own_vat
      Valvat.new(vat_number).exists?(requester_vat: own_vat)
    else
      Valvat.new(vat_number).exists?(detail: true)
    end
  end

  private

  # Calculates VAT percentage.
  #
  # country_code - ISO country code.
  # vat_registered   - true if customer is vat registered
  #
  # Returns an integer (percentage).
  def vat_rate(country_code, vat_registered)
    # Both individuals and companies pay VAT
    # in a country where you are VAT registered.
    if configuration_service.registered_countries.include?(country_code)
      VAT_RATES[country_code]
    elsif eu?(country_code)
      # Companies in other EU countries don't need to pay VAT.
      if vat_registered
        0
      # Individuals in other EU countries do need to pay VAT.
      else
        VAT_RATES[configuration_service.primary_country]
      end
    # All non-EU customers don't need to pay VAT.
    else
      0
    end
  end

  def eu?(country_code)
    Valvat::Utils::EU_COUNTRIES.include?(country_code)
  end

  def configuration_service
    @configuration_service ||= ConfigurationService.new
  end
end
