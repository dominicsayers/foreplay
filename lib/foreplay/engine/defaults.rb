module Foreplay
  class Engine
    module Defaults
      include Foreplay

      DEFAULT_CONFIG_FILE = "#{Dir.getwd}/config/foreplay.yml".freeze
      DEFAULTS_KEY        = 'defaults'.freeze

      def defaults
        return @defaults if @defaults

        # Establish defaults
        # First the default defaults
        @defaults = {
          'name'            =>  File.basename(Dir.getwd),
          'environment'     =>  environment,
          'port'            =>  DEFAULT_PORT,
          'config'          =>  []
        }

        @defaults['env'] = secrets
        @defaults['application'] = secrets
        @defaults = @defaults.supermerge(roles_all[DEFAULTS_KEY]) if roles_all.key? DEFAULTS_KEY
        @defaults = @defaults.supermerge(roles[DEFAULTS_KEY])     if roles.key? DEFAULTS_KEY
        @defaults
      end

      # Secret environment variables
      def secrets
        @secrets ||= (Foreplay::Engine::Secrets.new(environment, roles_all['secrets']).fetch || {})
      end

      def roles
        @roles ||= roles_all[environment]
      end

      def roles_all
        return @roles_all if @roles_all
        @roles_all = YAML.safe_load(File.read(config_file), [Date, Symbol, Time], [], true)

        # This environment
        unless @roles_all.key? environment
          terminate("No deployment configuration defined for #{environment} environment.\nCheck #{config_file}")
        end

        @roles_all
      rescue Errno::ENOENT
        terminate "Can't find configuration file #{config_file}.\n"\
          'Please run foreplay setup or create the file manually.'
      rescue Psych::SyntaxError
        terminate "I don't understand the configuration file #{config_file}.\n"\
          'Please run foreplay setup or edit the file manually.'
      end

      def config_file
        @config_file ||= (filters['config_file'] || DEFAULT_CONFIG_FILE)
      end
    end
  end
end
