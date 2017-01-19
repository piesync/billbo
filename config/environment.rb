$environment ||= (ENV['RACK_ENV'] || :development).to_sym
$token = ENV['API_TOKEN'] || 'billbo'

# Include lib
%w{app lib config}.each do |dir|
  $: << File.expand_path("../../#{dir}", __FILE__)
end

# Bundle (gems)
require 'boot'

I18n.config.enforce_available_locales = true

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
Stripe.api_version = '2015-10-16'

# Configure Shrimp
Shrimp.configure do |config|
  config.format      = 'A4'
  config.zoom        = 1
  config.orientation = 'portrait'
end

# Configure Money
Money.default_bank = EuCentralBank.new

# Configure Timeouts for VIES checks
{
  open_timeout: 10,
  read_timeout: 10
}.each do |key, d|
  Valvat::Lookup.client.globals[key] = d
end

# Configure Rumor
require 'rumor/async/sucker_punch'

# DB schema
require 'schema'

# Models
require 'invoice'

# Invoice generation.
require 'invoice_file_uploader'
require 'invoice_cloud_uploader'

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
require 'plugins/s3' if Configuration.s3?

# The Rack app
require 'rack_app'

# Cronjob
require 'job'

# Preload and validate configuration
Configuration.preload
raise 'configuration not valid' unless Configuration.valid?

# Disconnect before forking.
Configuration.db.disconnect
