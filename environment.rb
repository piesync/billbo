require 'bundler/setup'

# Require needed gems.
Bundler.require(:default, $environment)

# Environment Variables.
STRIPE_SECRET_KEY = ENV['STRIPE_SECRET_KEY'] || 'sk_test_SY84Wlp5UbI0Zv8rhGPkrqPv'

# Configure Stripe.
Stripe.api_key = STRIPE_SECRET_KEY

# Include lib.
$: << File.expand_path('../lib', __FILE__)

# Services.
require 'vat_service'
require 'vat_subscription_service'

# The main app.
require './app'
