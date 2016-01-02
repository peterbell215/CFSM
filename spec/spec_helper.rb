require 'bundler/setup'
Bundler.setup

require 'rspec/wait'

RSpec.configure do |c|
  c.example_status_persistence_file_path = 'rspec_failures.txt'
  c.wait_timeout = 60 # seconds
end