# Environment.
require './environment'

run Rack::URLMap.new(
  '/' => App,
  '/hooks' => Hooks
)
