$environment ||= :development

require 'bundler/setup'

# Require needed gems.
Bundler.require(:default, $environment)

# Configure Stripe.
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

# Configure Sequel.
$db = if [:test, :development].include?($environment.to_sym)
  Sequel.connect('sqlite://invoices.db')
end

# Include lib.
$: << File.expand_path('../app', __FILE__)
$: << File.expand_path('../lib', __FILE__)

# Models.
require 'invoice'

# Services.
require 'vat_service'
require 'vat_subscription_service'
require 'invoice_service'

# The Apis.
require 'base'
require 'hooks'
require 'app'
