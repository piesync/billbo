list = Stripe::Subscription.list
while list
  list.each do |s|
    if s.schedule && s.tax_percent && s.tax_percent != 0
      schedule = Stripe::SubscriptionSchedule.retrieve(s.schedule)
      if schedule.phases.any? { |p| p.tax_percent != s.tax_percent }
        print "#{s.id} tax_percent not aligned (#{s.tax_percent}) ..."

        schedule.phases.each do |phase|
          phase.tax_percent = s.tax_percent
        end

        schedule.save

        puts "fixed"
      end
    end
  end

  if list.has_more?
    list = list.next_page
  else
    break
  end
end
