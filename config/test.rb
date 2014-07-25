require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'minitest/spec'
require 'minitest/autorun'
require 'mocha/mini_test'

$db = Sequel.connect('sqlite://tmp/invoices_test.db')

# Configure VCR.
VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.default_cassette_options = {
    record: :once,
    allow_unused_http_interactions: false
  }

  c.filter_sensitive_data('<AUTH>') do |interaction|
    (interaction.request.headers['Authorization'] || []).first
  end

  c.ignore_hosts 'codeclimate.com'
end

# Minitest clear db hook
module MiniTestHooks
  def setup
    $db[:invoices].delete
  end
end

# Include these hooks in every testcase.
MiniTest::Spec.send :include, MiniTestHooks
