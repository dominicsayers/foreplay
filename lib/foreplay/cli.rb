require 'thor'
require 'foreplay'
require 'foreplay/setup'

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

    method_option :name,        :aliases => "-n" #,   :default => File.basename(Dir.getwd)
    method_option :repository,  :aliases => "-r"
    method_option :user,        :aliases => "-u"
    method_option :password,    :aliases => "-p"
    method_option :path,        :aliases => "-f"
    method_option :servers,     :aliases => "-s", :type => :array
    method_option :db_adapter,  :aliases => "-a"#,  :default => 'postgres'
    method_option :db_encoding, :aliases => "-e"#,  :default => 'utf-8'
    method_option :db_name,     :aliases => "-d"
    method_option :db_pool                      , :type => :numeric#,  :default => 5
    method_option :db_host,     :aliases => "-h"
    method_option :db_user
    method_option :db_password

    def setup
      Foreplay::Setup.start
    end
  end
end
