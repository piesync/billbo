source 'https://rubygems.org'
ruby '2.2.3'

gemspec

gem 'dotenv'
gem 'activesupport'
gem 'sinatra', :require => 'sinatra/base'
gem 'stripe'
gem 'valvat'
gem 'multi_json'
gem 'oj'
gem 'sequel'
gem 'rumor', github: 'piesync/rumor'
gem 'sucker_punch'
gem 'analytics-ruby', :require => 'segment'

gem 'sqlite3', group: [:test, :development]
gem 'rake', group: [:test, :development]

gem 'shrimp'
gem 'carrierwave'
gem 'fog'
gem 'slim'
gem 'money'
gem 'eu_central_bank'
gem 'countries', github: 'challengee/countries'

group :test do
  gem 'webmock', github: 'bblimke/webmock'
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
  gem 'pg'
  gem 'puma'
  gem 'sentry-raven', :git => "https://github.com/getsentry/raven-ruby.git", :require => 'raven'
end
