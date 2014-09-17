class AnalyticsChannel < Rumor::Channel

  def initialize(segmentio)
    @segmentio = segmentio
  end

  on(:charge_succeeded) do |rumor|
    track_revenue(charge: rumor.subject)
  end

  on(:charge_refunded) do |rumor|
    track_revenue(charge: rumor.subject, negative: true)
  end

  on(:customer_subscription_created) do |rumor|
  end

  on(:customer_subscription_updated) do |rumor|
  end

  on(:customer_subscription_deleted) do |rumor|
  end

  private

  def track_revenue(charge:, negative: false)
    charge = Stripe::Charge.construct_from(charge)

    # Get analytics id based on Stripe customer.
    analytics_id = get_analytics_id_for_customer(charge.customer)

    # Revenue from cents.
    revenue = charge.amount / 100.0
    revenue = -revenue if negative

    # We need to subtract the vat amount before tracking it.
    # Subtracts 0 if vat_amount is nil.
    # TK can we do this using DB only? issue #26
    invoice = Stripe::Invoice.retrieve(charge.invoice)
    vat = invoice.metadata[:vat_amount].to_i / 100.0
    vat = -vat if negative
    revenue -= vat

    # Track.
    track analytics_id, 'revenue changed',
      revenue: revenue,
      currency: invoice.currency,
      vat_amount: vat,
      vat_rate: invoice.metadata[:vat_rate] || '0',
      total: revenue + vat
  end

  def get_analytics_id_for_customer(customer_id)
    customer = Stripe::Customer.retrieve(customer_id)
    customer.metadata[:analytics_id] || customer.email
  end

  def track user, event, properties = {}
    @segmentio.track \
      user_id: user,
      event: event,
      properties: properties
  end
end
