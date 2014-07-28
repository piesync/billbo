class AnalyticsChannel < Rumor::Channel

  on(:charge_succeeded) do |rumor|
    analytics_id = get_analytics_id_for_customer(rumor.subject[:customer])

    revenue = rumor.subject[:amount] / 100.0

    track analytics_id, 'revenue changed', revenue: revenue
  end

  on(:charge_refunded) do |rumor|
    analytics_id = get_analytics_id_for_customer(rumor.subject[:customer])

    revenue = -rumor.subject[:amount] / 100.0

    track analytics_id, 'revenue changed', revenue: revenue
  end

  on(:customer_subscription_created) do |rumor|
  end

  on(:customer_subscription_updated) do |rumor|
  end

  on(:customer_subscription_deleted) do |rumor|
  end

  private

  def get_analytics_id_for_customer(customer_id)
    customer = Stripe::Customer.retrieve(customer_id)
    customer.metadata[:analytics_id] || customer.email
  end

  def track user, event, properties = {}
    AnalyticsRuby.track \
      user_id: user.email,
      event: event,
      properties: properties
  end
end
