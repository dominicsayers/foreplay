require 'active_support/inflector'
require 'colorize'
require 'hashie/mash'

module Foreplay
  class Config
    def self.check *args
      options = Hashie::Mash[args.first]

      # Explain what we're going to do
      environments  = explanatory_text options.environment, 'environment'
      roles         = explanatory_text options.role, 'role'
      servers       = explanatory_text options.server, 'server'
      puts 'Checking configuration for %s, %s, %s' % [environments, roles, servers]

      'Not finished'
    end

    private

    def self.explanatory_text(value, singular_word)
      value.nil? ? "all #{singular_word.pluralize}" : "#{value.dup.yellow} #{singular_word}"
    end
  end
end
