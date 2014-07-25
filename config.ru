# Environment.
require './environment'

use Rack::Auth::Basic, 'Billbo' do |_, token|
  token == (ENV['API_TOKEN'] || 'billbo')
end

run Rack::URLMap.new(
  '/' => App,
  '/hook' => Hooks
)
