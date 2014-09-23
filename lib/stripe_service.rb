# This Service handles creating and updating Stripe subscriptions,
# because these 2 actions have VAT/invoice consequences.
class StripeService

  # customer_id - Stripe customer id.
  def initialize(customer_id:)
    @customer_id = customer_id
  end

  # When creating a subscription in Stripe, an invoice is created,
  # and paid (charged) IMMEDIATELY. This would result in an invoice
  # without VAT charges.
  #
  # Our solution is to first add VAT charges to the upcoming invoice
  # and then subscribing the customer to the plan.
  #
  # options - All options that can be passed to Stripe subscription create.
  #
  # Returns the created Stripe subscription and invoice.
  def create_subscription(options)
    # Get the plan.
    plan = Stripe::Plan.retrieve(options[:plan])

    # Charge VAT in advance because subscription call will create and pay an invoice.
    # TK actually we need to apply VAT for invoiceitems that are pending and scheduled
    # for the next invoice.
    # Do not charge VAT if the plan or the subscription is still in trial (invoice will come later).
    vat, invoice_item = charge_vat_of_plan(plan) unless \
      plan.trial_period_days || (options[:trial_end] && options[:trial_end] != 'now')

    # Start subscription.
    # This call automatically creates an invoice, always.
    subscription = customer.subscriptions.create(options)

    # Get the last invoice to snapshot customer data.
    _last_invoice = last_invoice
    snapshot_customer(_last_invoice)

    [subscription, _last_invoice]
  rescue Stripe::StripeError => e
    # Something failed in Stripe, if we already charged for VAT,
    # we need to rollback this. As we may charge twice later otherwise.
    invoice_item.delete if invoice_item
    raise e
  end

  # Applies VAT to a Stripe invoice if necessary.
  # Copies customer metadata to the invoice, to make it immutable
  # for the invoice (in case the customer's metadata changes).
  #
  # invoice - A Stripe invoice object.
  #
  # Returns the finalized stripe invoice.
  def apply_vat(invoice_id:)
    stripe_invoice = Stripe::Invoice.retrieve(invoice_id)

    # Add VAT to the invoice.
    vat, invoice_item = charge_vat(stripe_invoice.subtotal,
      invoice_id: invoice_id, currency: stripe_invoice.currency)

    # Snapshot customer data.
    snapshot_customer(stripe_invoice)

    Stripe::Invoice.retrieve(invoice_id)
  end

  # Snapshots the final correct state of an invoice. It
  # figures out the right amount of VAT and discount.
  #
  # stripe_invoice - The Stripe invoice to snapshot.
  #
  # Returns a hash that contains all snapshotted data.
  def snapshot_final(stripe_invoice:, **extra)
    # Start off with the existing and extra metadata.
    metadata = stripe_invoice.metadata.to_h
    metadata.merge!(extra)

    # Find the VAT invoice item.
    vat_line = stripe_invoice.lines.find { |line| line.metadata[:type] == 'vat' }
    other_lines = stripe_invoice.lines.to_a - [vat_line]
    subtotal = other_lines.map(&:amount).inject(:+)

    # Recalculate discount based on the sum of all lines besides the vat line.
    discount = calculate_discount(subtotal, stripe_invoice.discount.coupon) if stripe_invoice.discount
    subtotal_after_discount = subtotal - discount.to_i

    metadata.merge!(subtotal: subtotal)

    # If there is vat and a discount, we need to recalculate VAT and the discount.
    more = if vat_line && stripe_invoice.discount
      # Recalculate VAT based on the total after discount
      vat_amount, vat_rate = calculate_vat(subtotal_after_discount).to_a

      # Modify discount so that the total amount checks out.
      discount += stripe_invoice.total - (subtotal_after_discount + vat_amount)
      subtotal_after_discount = subtotal - discount

      {
        discount_amount: discount,
        subtotal_after_discount: subtotal_after_discount,
        vat_amount: vat_amount,
        vat_rate: vat_rate
      }
    else
      {
        discount_amount: stripe_invoice.subtotal - stripe_invoice.total,
        subtotal_after_discount: subtotal_after_discount,
        vat_amount: (vat_line && vat_line.metadata[:amount]).to_i,
        vat_rate: (vat_line && vat_line.metadata[:rate]).to_i
      }
    end

    stripe_invoice.metadata = metadata.merge!(more)
    stripe_invoice.save

    metadata
  end

  private

  def last_invoice
    Stripe::Invoice.all(customer: customer.id, limit: 1).first
  end

  def snapshot_customer(stripe_invoice)
    metadata = stripe_invoice.metadata.to_h
    metadata.merge!(customer.metadata.to_h)
    stripe_invoice.metadata = metadata
    stripe_invoice.save
    metadata
  end

  def charge_vat_of_plan(plan)
    # Add vat charges.
    charge_vat(plan.amount, currency: plan.currency)
  end

  # Charges VAT for a certain amount.
  #
  # amount - Amount to charge VAT for.
  # invoice_id - optional invoice_id (upcoming invoice by default).
  #
  # Returns a VatCharge object.
  def charge_vat(amount, currency:, invoice_id: nil)
    # Calculate the amount of VAT to be paid.
    vat = calculate_vat(amount)

    # Add an invoice item to the invoice with this amount.
    invoice_item = Stripe::InvoiceItem.create(
      customer: customer.id,
      invoice: invoice_id,
      amount: vat.amount,
      currency: currency,
      description: "VAT (#{vat.rate}%)",
      metadata: {
        type: 'vat',
        amount: vat.amount,
        rate: vat.rate
      }
    ) unless vat.amount.zero?

    [vat, invoice_item]
  end

  def calculate_vat(amount)
    vat_service.calculate \
      amount: amount,
      country_code: customer.metadata[:country_code],
      vat_registered: (customer.metadata[:vat_registered] == 'true')
  end

  # Calculates the amount of discount given on an amount
  # with a certain Stripe coupon.
  def calculate_discount(amount, coupon)
    if coupon.percent_off
      ((amount*coupon.percent_off)/100.0).round
    else
      amount - coupon.amount_off
    end
  end

  def customer
    @customer ||= Stripe::Customer.retrieve(@customer_id)
  end

  def vat_service
    @vat_service ||= VatService.new
  end
end
