require 'thor'
require 'foreplay'
require 'foreplay/generators/setup'

module Foreplay
  class CLI < Thor
    desc 'check', 'Checks if configuration is OK'

    method_option :environment, :aliases => "-e"
    method_option :role,        :aliases => "-r"
    method_option :server,      :aliases => "-s"

    def check
      puts Foreplay::Config.check options
    end

    desc 'setup', 'Create the Foreplay config file'

    def setup
      Foreplay::Generators::Setup.start
    end
  end
end
