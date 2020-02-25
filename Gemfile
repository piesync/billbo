source 'https://rubygems.org'
ruby '2.6.5'

gemspec

gem 'dotenv'
gem 'activesupport'
gem 'sinatra', :require => 'sinatra/base'
gem 'stripe'
gem 'rest-client'
gem 'valvat'
gem 'multi_json'
gem 'oj'
gem 'sequel'
gem 'pg'
gem 'rumor', github: 'piesync/rumor'
gem 'sucker_punch'
gem 'analytics-ruby', '>= 2.2.0', :require => 'segment/analytics'

gem 'rake'

gem 'shrimp'
gem 'carrierwave'
gem 'fog-aws'
gem 'slim'
gem 'money'
gem 'eu_central_bank'
gem 'countries', github: 'challengee/countries'

gem 'tox', github: 'piesync/tox'
gem 'savon'

group :test do
  gem 'webmock'
  gem 'vcr'
  gem 'mocha'
  gem 'rack-test', :require => 'rack/test'
  gem 'capybara'
  gem 'poltergeist'
  gem 'timecop'
end

group :development do
  gem 'guard'
  gem 'guard-minitest'
  gem 'shotgun'
  gem 'choice'
end

group :production do
  gem 'puma'
  gem 'sentry-raven'
end
