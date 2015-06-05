lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'foreplay/version'

Gem::Specification.new do |spec|
  spec.name          = 'foreplay'
  spec.version       = Foreplay::VERSION
  spec.authors       = ['Xenapto']
  spec.email         = ['developers@xenapto.com']
  spec.description   = 'Deploying Rails projects to Ubuntu using Foreman'
  spec.summary       = 'Example: foreplay deploy production'
  spec.homepage      = 'https://github.com/Xenapto/foreplay'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin\/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features|coverage)\/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'foreman', '>= 0.76', '< 1.0'
  spec.add_runtime_dependency 'ssh-shell', '>= 0.4', '< 1.0'
  spec.add_runtime_dependency 'activesupport', '>= 3.2', '< 5.0'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.4'
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_development_dependency 'cucumber', '~> 2.0'
  spec.add_development_dependency 'aruba', '~> 0.6'
  spec.add_development_dependency 'gem-release', '~> 0.7'
  spec.add_development_dependency 'simplecov', '~> 0.10'
  spec.add_development_dependency 'coveralls', '~> 0.8'
  spec.add_development_dependency 'rubocop', '~> 0.30'
  spec.add_development_dependency 'guard', '~> 2.7'
  spec.add_development_dependency 'guard-rspec', '~> 4.3'
  spec.add_development_dependency 'guard-rubocop', '~> 1.2'
  spec.add_development_dependency 'guard-cucumber', '~> 1.6'
end
