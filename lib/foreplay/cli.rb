require 'thor'
require 'foreplay'

module Foreplay
  class CLI < Thor
    desc 'deploy ENVIRONMENT', 'Deploys to specified environment'

    method_option :role,        :aliases => '-r'
    method_option :server,      :aliases => '-s'

    def deploy(environment)
      Foreplay::Deploy.start [:deploy, environment, options]
    end

    desc 'check ENVIRONMENT', 'Checks if configuration is OK for specified environment'

    method_option :role,        :aliases => '-r'
    method_option :server,      :aliases => '-s'

    def check(environment)
      Foreplay::Deploy.start [:check, environment, options]
    end

    desc 'setup', 'Create the Foreplay config file'

    method_option :name,        :aliases => '-n'
    method_option :repository,  :aliases => '-r'
    method_option :user,        :aliases => '-u'
    method_option :password
    method_option :path,        :aliases => '-f'
    method_option :port,        :aliases => '-p', :type => :numeric
    method_option :servers,     :aliases => '-s', :type => :array
    method_option :db_adapter,  :aliases => '-a'
    method_option :db_encoding, :aliases => '-e'
    method_option :db_name,     :aliases => '-d'
    method_option :db_pool                      , :type => :numeric
    method_option :db_host,     :aliases => '-h'
    method_option :db_user
    method_option :db_password

    def setup
      Foreplay::Setup.start
    end
  end
end
