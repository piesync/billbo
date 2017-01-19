class VatService
  ViesDown = Class.new(StandardError)
  VatCharge = Struct.new(:amount, :rate)

  # http://ec.europa.eu/taxation_customs/resources/documents/taxation/vat/how_vat_works/rates/vat_rates_en.pdf
  VAT_RATES = {
    'BE' => 21, # Belgium
    'BG' => 20, # Bulgaria
    'CZ' => 21, # Czech Republic
    'DK' => 25, # Denmark
    'DE' => 19, # Germany
    'EE' => 20, # Estonia
    'EL' => 23, # Greece
    'ES' => 21, # Spain
    'FR' => 20, # France
    'HR' => 25, # Croatia
    'IE' => 23, # Ireland
    'IT' => 22, # Italy
    'CY' => 19, # Cryprus
    'LV' => 21, # Latvia
    'LT' => 21, # Lithuania
    'LU' => 17, # Luxembourg
    'HU' => 27, # Hungary
    'MT' => 18, # Malta
    'NL' => 21, # Netherlands
    'AT' => 20, # Austria
    'PL' => 23, # Poland
    'PT' => 23, # Portugal
    'RO' => 24, # Romania
    'SI' => 22, # Slovenia
    'SK' => 20, # Slovakia
    'FI' => 24, # Finland
    'SE' => 25, # Sweden
    'GB' => 20  # United Kingdom
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
  rescue Savon::Error => e
    puts "Failed checking VAT validity of #{var_number}: #{e.to_s}"

    Valvat.new(vat_number).valid_checksum?
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
  def load_vies_data(invoice:)
    details = self.details(vat_number: invoice.customer_vat_number,
      own_vat: Configuration.seller_vat_number)

    # details can still be nil here if a VAT number does not exist.
    # This case can still happen here because the VIES service
    # was down earlier and we used only checksum to pass the VAT number.
    if details
      invoice.update \
        vies_company_name: details[:name].try(:strip).presence,
        vies_address: details[:address].try(:strip).presence,
        vies_request_identifier: details[:request_identifier]
    end
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
