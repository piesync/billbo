$environment ||= (ENV['RACK_ENV'] || :development).to_sym

# Include lib
%w{app lib config}.each do |dir|
  $: << File.expand_path("../../#{dir}", __FILE__)
end

# Bundle (gems)
require 'boot'

# Load Environment variables from env files
Dotenv.load(
  File.expand_path("../../.env.#{$environment}", __FILE__),
  File.expand_path('../../.env',  __FILE__)
)

# Configuration
require 'configuration_service'
require 'configuration'

Configuration.from_env

# Connect to database
Configuration.db = Sequel.connect(Configuration.database_url)

# Configure Stripe
Stripe.api_key = Configuration.stripe_secret_key

# Configure Rumor
require 'rumor/async/sucker_punch'

# DB schema
require 'schema'

# Models
require 'invoice'

# Services
require 'vat_service'
require 'stripe_service'
require 'invoice_service'

# The Apis
require 'base'
require 'hooks'
require 'app'

# Load plugins
require 'plugins/sentry' if Configuration.sentry?
require 'plugins/segmentio' if Configuration.segmentio?

# Preload and validate configuration
Configuration.preload
raise 'configuration not valid' unless Configuration.valid?

# Disconnect before forking.
Configuration.db.disconnect
