# Environment.
require './config/environment'

use Raven::Rack if ENV['SENTRY_DSN']

secure = Rack::Builder.app do
  use Rack::Auth::Basic, 'Billbo' do |_, token|
    token == (ENV['API_TOKEN'] || 'billbo')
  end

  run Rack::URLMap.new(
    '/' => App,
    '/hook' => Hooks
  )
end

run Rack::URLMap.new(
  '/' => secure,
  '/ping' => lambda { |env| [200, {}, ''] }
)
