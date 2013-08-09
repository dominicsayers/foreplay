require 'hashie/mash'
require 'thor/group'

module Foreplay
  class Setup < Thor::Group
    include Thor::Actions

    class_option :name,         :default => File.basename(Dir.getwd)
    class_option :repository
    class_option :user
    class_option :password
    class_option :path
    class_option :servers
    class_option :db_adapter,   :default => 'postgres'
    class_option :db_encoding,  :default => 'utf-8'
    class_option :db_name
    class_option :db_pool,      :default => 5
    class_option :db_host
    class_option :db_user
    class_option :db_password

    def self.source_root
      File.dirname(__FILE__)
    end

    def config
p options # debug
      template('config/foreplay.yml', 'config/foreplay.yml')
    end
  end
end
