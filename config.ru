# Environment.
require './config/environment'

use Rack::Auth::Basic, 'Billbo' do |_, token|
  token == $token
end

use Raven::Rack if ENV['SENTRY_DSN']

use Rack::Static, :urls => ['/assets']

run Rack::URLMap.new(
  '/' => App,
  '/hook' => Hooks
)
