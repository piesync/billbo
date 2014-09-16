$environment ||= (ENV['RACK_ENV'] || :development).to_sym
$token = ENV['API_TOKEN'] || 'billbo'

# Include lib
%w{app lib config}.each do |dir|
  $: << File.expand_path("../../#{dir}", __FILE__)
end

# Bundle (gems)
require 'boot'

# Require needed active support bits
require 'active_support/core_ext/integer'

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

# Configure Shrimp
Shrimp.configure do |config|
  config.format      = 'A4'
  config.zoom        = 1
  config.orientation = 'portrait'
end

# Configure Rumor
require 'rumor/async/sucker_punch'

# DB schema
require 'schema'

# Models
require 'invoice'

# Invoice generation.
require 'invoice_uploader'

# Services
require 'vat_service'
require 'stripe_service'
require 'invoice_service'
require 'pdf_service'

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
