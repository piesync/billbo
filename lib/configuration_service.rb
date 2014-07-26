class ConfigurationService

  def primary_country
    @primary_country ||= Stripe::Account.retrieve().country
  end

  # TK extend to additional countries next to primary
  def registered_countries
    [ primary_country ]
  end

end
