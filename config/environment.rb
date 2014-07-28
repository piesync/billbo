$environment ||= (ENV['RACK_ENV'] || :development).to_sym

# Include lib.
%w{app lib config}.each do |dir|
  $: << File.expand_path("../../#{dir}", __FILE__)
end

# Bundle.
require 'boot'

# Configure Stripe.
Stripe.api_key = ENV['STRIPE_SECRET_KEY'] || 'dummy'

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
