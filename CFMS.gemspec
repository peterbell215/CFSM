# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'CFSM'
  spec.version       = '0.0.1'
  spec.authors       = ['Peter Bell']
  spec.email         = ['peter.bell215@gmail.com']
  spec.summary       = 'Provides a mechanism for defining systems of communicating finite state machines'
  spec.description   = <<DESCRIPTION
When trying to build systems that deal with real world scenarios (particularly embedded and communications),
then Communicating Finite State Machines is a powerful paradigm.  This library was created out of a desire to provide
an easy way within Ruby to construct systems of communicating finite state machines.
DESCRIPTION
  spec.homepage      = 'http://github.com/peterbell215/CFSM'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency "parslet", "~> 1.6"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec" "~>3.3"
end
