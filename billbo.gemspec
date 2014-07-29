# coding: utf-8
lib = File.expand_path('../client', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'billbo/version'

Gem::Specification.new do |spec|
  spec.name          = "billbo"
  spec.version       = Billbo::VERSION
  spec.authors       = ["Mattias Putman", "Tijs Planckaert"]
  spec.email         = ["mattias@piesync.com", "tijs@piesync.com"]
  spec.summary       = %q{Easy to use billing service for Stripe with VAT support}
  spec.homepage      = "https://github.com/piesync/billbo"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
    .select { |f| f.start_with?('client/') } + ['billbo.gemspec']
  spec.require_paths = ["client"]
end
