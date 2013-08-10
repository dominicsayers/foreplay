require 'thor/group'

module Foreplay
  class Setup < Thor::Group
    include Thor::Actions

    class_option :name,         :aliases => '-n', :default => File.basename(Dir.getwd)
    class_option :repository,   :aliases => '-r'
    class_option :user,         :aliases => '-u'
    class_option :password
    class_option :port,         :aliases => '-p', :default => 50000
    class_option :path,         :aliases => '-f'
    class_option :servers,      :aliases => '-s', :type => :array
    class_option :db_adapter,   :aliases => '-a', :default => 'postgresql'
    class_option :db_encoding,  :aliases => '-e', :default => 'utf8'
    class_option :db_pool,                        :default => 5
    class_option :db_name,      :aliases => '-d'
    class_option :db_host,      :aliases => '-h'
    class_option :db_user
    class_option :db_password

    def self.source_root
      File.dirname(__FILE__)
    end

    def config
      template('setup/foreplay.yml', 'config/foreplay.yml')
    end
  end
end
