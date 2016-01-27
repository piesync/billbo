require './config/environment'

execute = ARGV[1] == '--execute'

def vat_rate(customer)
  VatService.new.vat_rate(
    country_code: customer.metadata[:country_code],
    vat_registered: (customer.metadata[:vat_registered] == 'true')
  )
end

def safe(subject)
  begin
    yield
  rescue StandardError => e
    puts "Something went wrong with #{subject}!"
    puts e.message, *e.backtrace
  end
end

puts "Migrating subscriptions\n"

customers = Stripe::Customer.all(limit: 100)

while !customers.data.empty?
  customers.each do |customer|
    safe(customer.id) do
      vat_rate = vat_rate(customer)

      if !vat_rate.zero?
        customer.subscriptions.each do |subscription|
          puts "migrating #{subscription.id} subscription for #{customer.id} (#{customer.email})"
          puts "country: #{customer.metadata[:country_code]} vat: #{customer.metadata[:vat_registered]}"
          puts "vat: #{vat_rate}"

          if execute
            puts "EXEC"
            subscription.tax_percent = vat_rate
            subscription.save
          end

          puts
        end
      end
    end
  end

  # Fetch more customers.
  puts "Fetching more customers!"
  customers = Stripe::Customer.all(limit: 100, starting_after: customers.data.last.id)
end

puts "Migrating Unpaid invoices\n"

invoices = Stripe::Invoice.all(limit: 100)

while !invoices.data.empty?
  invoices.each do |invoice|
    safe(invoice.id) do
      # If the invoice is unpaid we can still fix taxes!
      # If VAT has been added already, remove it and readd using tax_percent.
      # This will allow us to deal with old VAT when the invoice gets paid.
      if !invoice.paid

        # Fetch the customer and see if VAT should be paid.
        customer = Stripe::Customer.retrieve(invoice.customer)
        vat_rate = vat_rate(customer)

        if line = invoice.lines.find { |line| line.metadata[:type] == 'vat' }
          item = Stripe::InvoiceItem.retrieve(line.id)
          puts "removing old VAT (#{item.metadata[:rate]}) from #{invoice.id} of #{customer.id} (#{customer.email})"

          if execute
            puts "EXEC"
            is_closed = invoice.closed

            # Reopen the invoice for modification if it was closed.
            if is_closed
              puts 'reopening invoice'
              invoice.closed = false
              invoice.save
            end

            item.delete

            if is_closed
              puts 'closing again'
              invoice.closed = true
              invoice.save
            end
          end
        end

        if !vat_rate.zero?
          # VAT needs to be added!
          puts "adding VAT to #{invoice.id} of #{customer.id} (#{customer.email})"
          puts "country: #{customer.metadata[:country_code]} vat: #{customer.metadata[:vat_registered]}"
          puts "vat: #{vat_rate}"

          if execute
            puts "EXEC"
            invoice.tax_percent = vat_rate
            invoice.save
          end

          puts
        end
      end
    end
  end

  # Fetch more invoices.
  puts "Fetching more invoices!"
  invoices = Stripe::Invoice.all(limit: 100, starting_after: invoices.data.last.id)
end
