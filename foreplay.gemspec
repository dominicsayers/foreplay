lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'foreplay/version'

Gem::Specification.new do |s|
  s.name          = 'foreplay'
  s.version       = Foreplay::VERSION
  s.authors       = ['Dominic Sayers']
  s.email         = ['dominic@sayers.cc']
  s.description   = 'Deploying Rails projects to Ubuntu using Foreman'
  s.summary       = 'Example: foreplay deploy production'
  s.homepage      = 'https://github.com/dominicsayers/foreplay'
  s.license       = 'MIT'

  s.files = `git ls-files`.split($RS).reject { |file| file =~ %r{^spec/} }
  s.test_files = []
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency 'foreman', '>= 0.76', '< 1.0'
  s.add_runtime_dependency 'ssh-shell', '>= 0.4', '< 1.0'
  s.add_runtime_dependency 'activesupport', '>= 3.2.22', '< 5.0'
end
