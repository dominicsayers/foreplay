source 'https://rubygems.org'
ruby RUBY_VERSION
gemspec

group :test do
  gem 'aruba'
  gem 'codeclimate-test-reporter'
  gem 'coveralls'
  gem 'cucumber'
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'simplecov'
end

local_gemfile = 'Gemfile.local'

if File.exist?(local_gemfile)
  eval(File.read(local_gemfile)) # rubocop:disable Security/Eval
end
