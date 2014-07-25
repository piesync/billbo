source 'https://rubygems.org'
ruby '2.1.1'

gem 'sinatra', :require => 'sinatra/base'
gem 'stripe'
gem 'valvat'
gem 'multi_json'
gem 'oj'
gem 'sequel'

gem 'sqlite3', group: [:test, :development]
gem 'rake', group: [:test, :development]

group :test do
  gem 'webmock'
  gem 'vcr'
  gem 'mocha', :require => 'mocha/mini_test'
  gem 'rack-test', :require => 'rack/test'
  gem 'guard'
  gem 'guard-minitest'
end

group :development do
  gem 'thin'
  gem 'shotgun'
end
