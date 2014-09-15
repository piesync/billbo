source 'https://rubygems.org'
ruby '2.1.1'

gemspec

gem 'activesupport', :require => 'active_support/all'
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
gem 'dotenv', group: [:test, :development]

gem 'shrimp'
gem 'carrierwave'
gem 'fog'
gem 'slim'
gem 'money'

group :test do
  gem 'webmock'
  gem 'vcr'
  gem 'mocha'
  gem 'rack-test', :require => 'rack/test'
  gem 'codeclimate-test-reporter', :require => false
end

group :development do
  gem 'guard'
  gem 'guard-minitest'
  gem 'thin'
  gem 'shotgun'
  gem 'choice'
end

group :production do
  gem 'pg'
  gem 'puma'
  gem 'sentry-raven', :git => "https://github.com/getsentry/raven-ruby.git", :require => 'raven'
end
