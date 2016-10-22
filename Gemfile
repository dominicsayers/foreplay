source 'https://rubygems.org'
ruby '2.1.9'
gemspec

group :test do
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'cucumber'
  gem 'aruba'
  gem 'simplecov'
  gem 'coveralls'
  gem 'codeclimate-test-reporter'
end

local_gemfile = 'Gemfile.local'

if File.exist?(local_gemfile)
  eval(File.read(local_gemfile)) # rubocop:disable Lint/Eval
end
