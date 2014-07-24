require 'minitest/spec'
require 'minitest/autorun'

$environment = :test
require './environment'

# Configure VCR.
VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.default_cassette_options = {
    record: :once,
    allow_unused_http_interactions: false
  }
end
