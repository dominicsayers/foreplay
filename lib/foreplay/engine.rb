require 'yaml'
require 'string'
require 'hash'

class Foreplay::Engine
  include Foreplay
  attr_reader :mode, :environment, :filters

  DEFAULT_CONFIG_FILE = "#{Dir.getwd}/config/foreplay.yml"
  DEFAULTS_KEY        = 'defaults'

  def initialize(e, f)
    @environment  = e
    @filters      = f
  end

  def deploy
    @mode = :deploy
    execute
  end

  def check
    @mode = :check
    execute
  end

  def execute
    puts "#{mode.capitalize}ing #{environment.dup.yellow} environment, "\
         "#{explanatory_text(filters, 'role')}, #{explanatory_text(filters, 'server')}"

    actionable_roles.map { |role, instructions| threads(role, instructions) }.flatten.each(&:join)

    puts mode == :deploy ? 'Finished deployment' : 'Deployment configuration check was successful'
  end

  private

  def actionable_roles
    roles.select { |role, _i| role != DEFAULTS_KEY && role != filters['role'] }
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

  def config_file
    @config_file ||= (filters['config_file'] || DEFAULT_CONFIG_FILE)
  end

  def defaults
    return @defaults if @defaults

    # Establish defaults
    # First the default defaults
    @defaults = {
      'name'        =>  File.basename(Dir.getwd),
      'environment' =>  environment,
      'env'         =>  { 'RAILS_ENV' => environment },
      'port'        =>  50_000
    }

    @defaults['env'].merge! secrets
    @defaults['application'] = secrets
    @defaults = @defaults.supermerge(roles_all[DEFAULTS_KEY]) if roles_all.key? DEFAULTS_KEY
    @defaults = @defaults.supermerge(roles[DEFAULTS_KEY])     if roles.key? DEFAULTS_KEY
    @defaults
  end

  # Secret environment variables
  def secrets
    @secrets ||= Foreplay::Engine::Secrets.new(environment, roles_all['secrets']).fetch || {}
  end

  def verbose
    @verbose ||= filters.key?('verbose')
  end

  def roles
    @roles ||= roles_all[environment]
  end

  def roles_all
    return @roles_all if @roles_all

    @roles_all = YAML.load(File.read(config_file))

    # This environment
    unless @roles_all.key? environment
      terminate("No deployment configuration defined for #{environment} environment.\nCheck #{config_file}")
    end

    @roles_all
  rescue Errno::ENOENT
    terminate "Can't find configuration file #{config_file}.\nPlease run foreplay setup or create the file manually."
  rescue Psych::SyntaxError
    terminate "I don't understand the configuration file #{config_file}.\n"\
      'Please run foreplay setup or edit the file manually.'
  end
end
