lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'foreplay/version'

Gem::Specification.new do |spec|
  spec.name          = 'foreplay'
  spec.version       = Foreplay::VERSION
  spec.authors       = ['Xenapto']
  spec.email         = ['developers@xenapto.com']
  spec.description   = %q{Deploying Rails projects to Ubuntu using Foreman}
  spec.summary       = %q{Example: foreplay push to production}
  spec.homepage      = 'https://github.com/Xenapto/foreplay'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features|coverage)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '~> 4.1.1'
  spec.add_runtime_dependency 'colorize', '~> 0.7.3'
  spec.add_runtime_dependency 'foreman', '~> 0.67.0'
  spec.add_runtime_dependency 'net-ssh-shell', '~> 0.2.0'
  #spec.add_runtime_dependency 'thor', '~> 0.19.1' # Dependency of foreman anyway

  spec.add_development_dependency 'bundler', '~> 1.6.2'
  spec.add_development_dependency 'rake', '~> 10.3.2'
  spec.add_development_dependency 'rspec', '~> 2.14.1'
  spec.add_development_dependency 'cucumber', '~> 1.3.15'
  spec.add_development_dependency 'aruba', '~> 0.5.4'
  spec.add_development_dependency 'gem-release', '~> 0.7.3'
  spec.add_development_dependency 'simplecov', '~> 0.8.2'
end
