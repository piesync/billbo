# Environment.
require './environment'

run Rack::URLMap.new(
  '/' => App,
  '/hook' => Hooks
)
