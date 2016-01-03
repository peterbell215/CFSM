require 'bundler/setup'
Bundler.setup

require 'simplecov'
SimpleCov.start do
  add_filter "/Examples/"
end

require 'rspec/wait'

RSpec.configure do |c|
  c.example_status_persistence_file_path = 'rspec_failures.txt'
  c.wait_timeout = 60 # seconds
end