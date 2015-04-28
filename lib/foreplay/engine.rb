require 'yaml'
require 'string'

class Foreplay::Engine
  include Foreplay
  attr_reader :environment, :filters, :mode

  DEFAULTS_KEY  = 'defaults'
  CONFIG_FILE   = "#{Dir.getwd}/config/foreplay.yml"

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
    # Explain what we're going to do
    puts "#{mode.capitalize}ing #{environment.dup.yellow} environment, "\
         "#{explanatory_text(filters, 'role')}, #{explanatory_text(filters, 'server')}"

    threads = []

    roles.each do |role, additional_instructions|
      next if role == DEFAULTS_KEY # 'defaults' is not a role
      next if filters.key?('role') && filters['role'] != role

      threads.concat Foreplay::Engine::Role.new(
        environment,
        mode,
        build_instructions(role, additional_instructions)
      ).threads
    end

    threads.each(&:join)

    puts mode == :deploy ? 'Finished deployment' : 'Deployment configuration check was successful'
  end

  # Returns a new hash with +hash+ and +other_hash+ merged recursively, including arrays.
  #
  #   h1 = { x: { y: [4,5,6] }, z: [7,8,9] }
  #   h2 = { x: { y: [7,8,9] }, z: 'xyz' }
  #   h1.supermerge(h2)
  #   #=> {:x=>{:y=>[4, 5, 6, 7, 8, 9]}, :z=>[7, 8, 9, "xyz"]}
  def supermerge(hash, other_hash)
    fail 'supermerge only works if you pass two hashes. '\
      "You passed a #{hash.class} and a #{other_hash.class}." unless hash.is_a?(Hash) && other_hash.is_a?(Hash)

    new_hash = hash.deep_dup.with_indifferent_access

    other_hash.each_pair do |k, v|
      tv = new_hash[k]

      if tv.is_a?(Hash) && v.is_a?(Hash)
        new_hash[k] = supermerge(tv, v)
      elsif tv.is_a?(Array) || v.is_a?(Array)
        new_hash[k] = Array.wrap(tv) + Array.wrap(v)
      else
        new_hash[k] = v
      end
    end

    new_hash
  end

  private

  def explanatory_text(hsh, key)
    hsh.key?(key) ? "#{hsh[key].dup.yellow} #{key}" : "all #{key.pluralize}"
  end

  def build_instructions(role, additional_instructions)
    instructions        = supermerge(defaults, additional_instructions).symbolize_keys
    instructions[:role] = role
    required_keys       = [:name, :environment, :role, :servers, :path, :repository]

    required_keys.each do |key|
      next if instructions.key? key
      terminate("Required key #{key} not found in instructions for #{environment} environment.\nCheck #{CONFIG_FILE}")
    end

    # Apply server filter
    instructions[:servers] &= server_filter if server_filter
    instructions
  end

  def server_filter
    @server_filter ||= filters['server'].split(',') if filters.key?('server')
  end

  def defaults
    return @defaults if @defaults

    # Establish defaults
    # First the default defaults
    @defaults = {
      name:         File.basename(Dir.getwd),
      environment:  environment,
      env:          { 'RAILS_ENV' => environment },
      port:         50_000
    }

    @defaults = supermerge(@defaults, roles_all[DEFAULTS_KEY]) if roles_all.key? DEFAULTS_KEY
    @defaults = supermerge(@defaults, roles[DEFAULTS_KEY])     if roles.key? DEFAULTS_KEY
  end

  def roles
    @roles ||= roles_all[environment]
  end

  def roles_all
    return @roles_all if @roles_all

    @roles_all = YAML.load(File.read(CONFIG_FILE))

    # This environment
    unless @roles_all.key? environment
      terminate("No deployment configuration defined for #{environment} environment.\nCheck #{CONFIG_FILE}")
    end

    @roles_all
  rescue Errno::ENOENT
    terminate "Can't find configuration file #{CONFIG_FILE}.\nPlease run foreplay setup or create the file manually."
  rescue Psych::SyntaxError
    terminate "I don't understand the configuration file #{CONFIG_FILE}.\n"\
      'Please run foreplay setup or edit the file manually.'
  end
end
