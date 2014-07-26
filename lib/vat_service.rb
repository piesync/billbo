class VatService
  VatCharge = Struct.new(:amount, :rate)

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
  # is_company   - true if customer is a company
  #
  # Returns amount of VAT payable (rounded down).
  def calculate(amount:, country_code:, is_company:)
    rate = vat_rate(country_code, is_company)
    VatCharge.new(amount*rate/100, rate)
  end

  # Checks if given VAT number is valid.
  def valid?(vat_number:)
    vies_valid = Valvat::Lookup.validate(vat_number)
    if vies_valid.nil?
      Valvat.new(vat_number).valid_checksum?
    else
      vies_valid
    end
  end

  private

  # Calculates VAT percentage.
  #
  # country_code - ISO country code.
  # is_company   - true if customer is a company
  #
  # Returns an integer (percentage).
  def vat_rate(country_code, is_company)
    # Both individuals and companies pay VAT
    # in a country where you are VAT registered.
    if configuration_service.registered_countries.include?(country_code)
      VAT_RATES[country_code]
    elsif eu?(country_code)
      # Companies in other EU countries don't need to pay VAT.
      if is_company
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
