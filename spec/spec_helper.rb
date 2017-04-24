# Configure Simplecov and Coveralls
unless ENV['NO_SIMPLECOV']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.start { add_filter '/spec/' }
  Coveralls.wear! if ENV['COVERALLS_REPO_TOKEN']
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
