$environment = :test
require_relative '../config/boot'

require 'minitest/spec'
require 'minitest/autorun'
require 'mocha/mini_test'
require 'webmock/minitest'
require 'capybara/poltergeist'

# Configure VCR
VCR.configure do |c|
  c.cassette_library_dir = (Pathname.new(__FILE__) + '../../spec/cassettes').to_s
  c.hook_into :webmock
  c.default_cassette_options = {
    record: :once,
    allow_unused_http_interactions: true
  }

  c.filter_sensitive_data('<AUTH>') do |interaction|
    (interaction.request.headers['Authorization'] || []).first
  end

  c.ignore_localhost = true
  c.ignore_hosts 'codeclimate.com'
end

VCR.use_cassette('configuration_preload') do
  require_relative '../config/environment'
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

# Configure Capybara
Capybara.default_driver = :poltergeist
Capybara.app = Configuration.app

# Override the Billbo host to the in-process capybara server
Configuration.host = "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
