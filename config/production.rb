$db = Sequel.connect(ENV['DATABASE_URL'])

# Configure Sentry.
if ENV['SENTRY_DSN']
  Raven.configure do |config|
    config.dsn = ENV['SENTRY_DSN']
  end
end
