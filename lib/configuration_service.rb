class ConfigurationService

  def account
    @primary_country ||= Stripe::Account.retrieve
  end
end
