require 'bundler/setup'

# Require needed gems.
Bundler.require(:default)

# Environment Variables.
STRIPE_SECRET_KEY = ENV['STRIPE_SECRET_KEY'] || 'sk_test_SY84Wlp5UbI0Zv8rhGPkrqPv'

# Include lib.
$: << File.expand_path('../lib', __FILE__)

# Services.
require 'vat_service'

# The main app.
require './app'
