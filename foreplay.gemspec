lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'foreplay/version'

Gem::Specification.new do |spec|
  spec.name          = "foreplay"
  spec.version       = Foreplay::VERSION
  spec.authors       = ["Xenapto"]
  spec.email         = ["developers@xenapto.com"]
  spec.description   = %q{Deploying Rails projects to Ubuntu using Foreman}
  spec.summary       = %q{Example: foreplay push to production}
  spec.homepage      = "https://github.com/Xenapto/foreplay"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'activesupport'
  spec.add_dependency 'colorize'
  spec.add_dependency 'foreman'
  spec.add_dependency 'net-ssh-shell'
  spec.add_dependency 'thor'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.6"
  spec.add_development_dependency "cucumber"
  spec.add_development_dependency "aruba"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "gem-release"
end
