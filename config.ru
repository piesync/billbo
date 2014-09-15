# Environment.
require './config/environment'

use Raven::Rack if Configuration.sentry?

secure = Rack::Builder.app do
  use Rack::Auth::Basic, 'Billbo' do |_, token|
    token == Configuration.api_token
  end

  run Rack::URLMap.new(
    '/' => App,
    '/hook' => Hooks
  )
end

run Rack::URLMap.new(
  '/' => secure,
  '/ping' => lambda { |env| [200, {}, ['OK']] }
)
