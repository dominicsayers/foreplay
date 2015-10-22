#- require 'foreplay/engine/defaults'
#- require 'foreplay/engine/logger'
#- require 'foreplay/engine/port'
#- require 'foreplay/engine/remote'
#- require 'foreplay/engine/role'
#- require 'foreplay/engine/secrets'
#- require 'foreplay/engine/server'
#- require 'foreplay/engine/step'

module Foreplay
  class Engine
    autoload :Defaults, 'foreplay/engine/defaults'
    autoload :Logger, 'foreplay/engine/logger'
    autoload :Port, 'foreplay/engine/port'
    autoload :Remote, 'foreplay/engine/remote'
    autoload :Role, 'foreplay/engine/role'
    autoload :Secrets, 'foreplay/engine/secrets'
    autoload :Server, 'foreplay/engine/server'
    autoload :Step, 'foreplay/engine/step'

    include Foreplay::Engine::Defaults
    attr_reader :mode, :environment, :filters

    def initialize(e, f)
      @environment  = e
      @filters      = f

      @defaults = nil
      @roles_all = nil
    end

    [:deploy, :check].each { |m| define_method(m) { execute m } }

    def execute(m)
      @mode = m
      puts "#{mode.capitalize}ing #{environment.dup.yellow} environment, "\
           "#{explanatory_text(filters, 'role')}, #{explanatory_text(filters, 'server')}"

      actionable_roles.map { |role, instructions| threads(role, instructions) }.flatten.each(&:join)

      puts mode == :deploy ? 'Finished deployment' : 'Deployment configuration check was successful'
    end

    private

    def actionable_roles
      roles.select { |role, _i| role != DEFAULTS_KEY && (filters.key?('role') ? role == filters['role'] : true) }
    end

    def threads(role, instructions)
      Foreplay::Engine::Role.new(
        environment,
        mode,
        build_instructions(role, instructions)
      ).threads
    end

    def explanatory_text(hsh, key)
      hsh.key?(key) ? "#{hsh[key].dup.yellow} #{key}" : "all #{key}s"
    end

    def build_instructions(role, additional_instructions)
      instructions            = defaults.supermerge(additional_instructions)
      instructions['role']    = role
      instructions['verbose'] = verbose
      required_keys           = %w(name environment role servers path repository)

      required_keys.each do |key|
        next if instructions.key? key
        terminate("Required key #{key} not found in instructions for #{environment} environment.\nCheck #{config_file}")
      end

      # Apply server filter
      instructions['servers'] &= server_filter if server_filter
      instructions
    end

    def server_filter
      @server_filter ||= filters['server'].split(',') if filters.key?('server')
    end

    def verbose
      @verbose ||= filters.key?('verbose')
    end
  end
end
