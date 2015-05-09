module Foreplay
  class Engine
    class Server
      include Foreplay::Engine::Port
      attr_reader :environment, :mode, :instructions, :server

      def initialize(e, m, i, s)
        @environment  = e
        @mode         = m
        @instructions = i
        @server       = s
      end

      def execute
        execute_announce
        foreman
        env

        Foreplay::Engine::Remote.new(server, steps, instructions).__send__ mode
      end

      def execute_announce
        preposition = mode == :deploy ? 'to' : 'for'
        puts "#{mode.capitalize}ing #{name.yellow} #{preposition} #{host.yellow} "\
            "for the #{role.dup.yellow} role in the #{environment.dup.yellow} environment"
      end

      def foreman
        instructions['foreman'] = {} unless instructions.key? 'foreman'

        instructions['foreman'].merge!(
          'app'   => current_service,
          'port'  => current_port,
          'user'  => user,
          'log'   => "$HOME/#{path}/#{current_port}/log"
        )
      end

      def env
        instructions['env'] = {} unless instructions.key? 'env'

        instructions['env'].merge!(
          'HOME'      => '$HOME',
          'SHELL'     => '$SHELL',
          'PATH'      => '$PATH:`which bundle`',
          'GEM_HOME'  => '$HOME/.rvm/gems/`rvm tools identifier`',
          'RAILS_ENV' => environment
        )
      end

      def role
        @role ||= instructions['role']
      end

      def user
        @user ||= instructions['user']
      end

      def path
        return @path if @path

        @path = instructions['path']
        @path.gsub! '%u', user
        @path.gsub! '%a', name
        @path
      end

      def steps
        @steps ||= YAML.load(
          ERB.new(
            File.read(
              "#{File.dirname(__FILE__)}/steps.yml"
            )
          ).result(binding)
        )
      end
    end
  end
end
