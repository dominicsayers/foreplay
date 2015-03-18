lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'foreplay/version'

Gem::Specification.new do |spec|
  spec.name          = 'foreplay'
  spec.version       = Foreplay::VERSION
  spec.authors       = ['Xenapto']
  spec.email         = ['developers@xenapto.com']
  spec.description   = 'Deploying Rails projects to Ubuntu using Foreman'
  spec.summary       = 'Example: foreplay push to production'
  spec.homepage      = 'https://github.com/Xenapto/foreplay'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features|coverage)\//)
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '>= 3.2'
  spec.add_runtime_dependency 'colorize', '>= 0.7'
  spec.add_runtime_dependency 'foreman', '>= 0.76'
  spec.add_runtime_dependency 'ssh-shell', '>= 0.4'
  # spec.add_runtime_dependency 'thor', '~> 0.19' # Dependency of foreman anyway

  spec.add_development_dependency 'bundler', '>= 1.6'
  spec.add_development_dependency 'rake', '>= 10.3'
  spec.add_development_dependency 'rspec', '>= 3.2'
  spec.add_development_dependency 'cucumber', '>= 1.3'
  spec.add_development_dependency 'aruba', '>= 0.5'
  spec.add_development_dependency 'gem-release', '>= 0.7'
  spec.add_development_dependency 'simplecov', '>= 0.7', '>= 0.7.1' # https://github.com/colszowka/simplecov/issues/281
  spec.add_development_dependency 'coveralls', '>= 0.7'
  spec.add_development_dependency 'rubocop', '> 0.29'
end
