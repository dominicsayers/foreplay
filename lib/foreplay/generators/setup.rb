require 'thor/group'

module Foreplay
  module Generators
    class Setup < Thor::Group
      include Thor::Actions

      Rails ||= nil

      def self.source_root
        File.dirname(__FILE__)
      end

      def create_config_file
        @name = Rails.nil? ? '%q{TODO: Add the app name}' : Rails.application.class.parent_name.underscore
        template('foreplay.yml', 'config/foreplay.yml')
      end
    end
  end
end
