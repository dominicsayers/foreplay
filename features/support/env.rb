# Initialize simplecov for coverage report.
require 'simplecov'
SimpleCov.start

require 'aruba/cucumber'

Before do
  @aruba_timeout_seconds = 50
end
