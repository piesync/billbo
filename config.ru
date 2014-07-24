require 'bundler/setup'

# Require needed gems.
Bundler.require(:default)

# Environment.
require './environment'

# The main app.
require './app'

run App
