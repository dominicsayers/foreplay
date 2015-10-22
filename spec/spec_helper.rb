# CodeClimate code coverage reporting (not used at the moment)
require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

unless ENV['NO_SIMPLECOV']
  require 'simplecov'

  if ENV['CIRCLE_ARTIFACTS']
    dir = File.join('..', '..', '..', ENV['CIRCLE_ARTIFACTS'], 'coverage')
    SimpleCov.coverage_dir(dir)
  end

  SimpleCov.start(:rails)
  Coveralls.wear!('rails') if ENV['COVERALLS_REPO_TOKEN']
end

require 'foreplay'

RSpec.configure do |config|
  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # Manually-added
  config.tty = true
end
