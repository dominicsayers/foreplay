require 'thor/group'

module Foreplay
  module Generators
    class Setup < Thor::Group
      include Thor::Actions

      def self.source_root
        File.dirname(__FILE__)
      end

      def create_config_file
        template('foreplay.yml', 'config/foreplay.yml')
      end
    end
  end
end
