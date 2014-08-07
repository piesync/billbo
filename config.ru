# Environment.
require './config/environment'

use Rack::Auth::Basic, 'Billbo' do |_, token|
  token == (ENV['API_TOKEN'] || 'billbo')
end

use Raven::Rack if ENV['SENTRY_DSN']

run Rack::URLMap.new(
  '/' => App,
  '/hook' => Hooks
)
