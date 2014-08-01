require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'minitest/spec'
require 'minitest/autorun'
require 'mocha/mini_test'
require 'webmock/minitest'

$db = Sequel.connect('sqlite://tmp/invoices_test.db')

# Configure Billbo.
Billbo.host = 'billbo.test'
Billbo.token = 'TOKEN'

# Configure VCR.
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

# Configure Analytics if enabled.
$analytics = Segment::Analytics.new({
  write_key: 'dummy',
  on_error: Proc.new { |status, msg| puts msg },
  stub: true
})

Rumor.register :analytics, AnalyticsChannel.new

# Minitest clear db hook
module MiniTestHooks
  def setup
    $db[:invoices].delete
  end
end

# Include these hooks in every testcase.
MiniTest::Spec.send :include, MiniTestHooks
