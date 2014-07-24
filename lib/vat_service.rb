class VatService
  BELGIUM = 'BE'

  # Calculates VAT amount based on country and whether the customer
  # is a company or not.
  #
  # amount       - Base amount that is VAT taxable in cents (or not).
  # country_code - ISO country code.
  # company      - true if customer is a company
  #
  # Returns amount of VAT payable (rounded down).
  def calculate(amount:, country_code:, company:)
    amount*vat_percentage(country_code, company)/100
  end

  private

  # Calculates VAT percentage.
  #
  # country_code - ISO country code.
  # company      - true if customer is a company
  #
  # Returns an integer (percentage).
  def vat_percentage(country_code, company)
    # Both individuals and companies pay VAT in Belgium.
    if country_code == BELGIUM
      21
    elsif eu?(country_code)
      # Companies in other EU countries don't need to pay VAT.
      if company
        0
      # Individuals in other EU countries do need to pay VAT.
      else
        21
      end
    # All non-EU customers don't need to pay VAT.
    else
      0
    end
  end

  def eu?(country_code)
    Valvat::Utils::EU_COUNTRIES.include?(country_code)
  end
end
