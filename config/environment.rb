$environment ||= (ENV['RACK_ENV'] || :development).to_sym

# Include lib.
%w{app lib config}.each do |dir|
  $: << File.expand_path("../../#{dir}", __FILE__)
end

# Bundle.
require 'boot'

# Channels.
require 'analytics_channel'

# Configure Stripe.
Stripe.api_key = ENV['STRIPE_SECRET_KEY'] || 'dummy'

# Configure Analytics if enabled.
if ENV['SEGMENTIO_WRITE_KEY']
  $analytics = Segment::Analytics.new({
    write_key: ENV['SEGMENTIO_WRITE_KEY'],
    on_error: Proc.new { |status, msg| puts msg }
  })

  Rumor.register :analytics, AnalyticsChannel.new
end

# Configure Rumor.
require 'rumor/async/sucker_punch'

# Environment specific config file.
require $environment.to_s

# DB schema.
require 'schema'

# Models.
require 'invoice'

# Services.
require 'configuration_service'
require 'vat_service'
require 'stripe_service'
require 'invoice_service'

# The Apis.
require 'base'
require 'hooks'
require 'app'

