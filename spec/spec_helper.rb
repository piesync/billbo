$environment = :test
require './config/boot'

require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'minitest/spec'
require 'minitest/autorun'
require 'mocha/mini_test'
require 'webmock/minitest'

# Configure VCR
VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.default_cassette_options = {
    record: :once,
    allow_unused_http_interactions: true
  }

  c.filter_sensitive_data('<AUTH>') do |interaction|
    (interaction.request.headers['Authorization'] || []).first
  end

  c.ignore_hosts 'codeclimate.com'
end

# Minitest clear db hook
module MiniTestHooks
  def setup
    Configuration.db[:invoices].delete
  end
end

# Include these hooks in every testcase.
MiniTest::Spec.send :include, MiniTestHooks

# Configure Billbo
Billbo.host = 'billbo.test'
Billbo.token = 'TOKEN'

VCR.use_cassette('configuration_preload') do
  require './config/environment'
end
