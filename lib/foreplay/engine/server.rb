require 'active_support/inflector'

class Foreplay::Engine::Server
  include Foreplay
  attr_reader :environment, :mode, :instructions, :server

  def initialize(e, m, i, s)
    @environment  = e
    @mode         = m
    @instructions = i
    @server       = s
  end

  def execute
    preposition = mode == :deploy ? 'to' : 'for'

    message = "#{mode.capitalize}ing #{name.yellow} #{preposition} #{host.yellow} "
    message += "for the #{role.dup.yellow} role in the #{environment.dup.yellow} environment"
    puts message

    instructions[:foreman]['app']   = current_service
    instructions[:foreman]['port']  = current_port
    instructions[:foreman]['user']  = user
    instructions[:foreman]['log']   = "$HOME/#{path}/#{current_port}/log"

    # Contents of .env file
    instructions[:env]['HOME']  = '$HOME'
    instructions[:env]['SHELL'] = '$SHELL'
    instructions[:env]['PATH']  = '$PATH:`which bundle`'

    Foreplay::Engine::Remote.new(server, steps, instructions).__send__ mode
  end

  def role
    @role ||= instructions[:role]
  end

  def user
    @user ||= instructions[:user]
  end

  def name
    @name ||= instructions[:name]
  end

  def path
    return @path if @path

    @path = instructions[:path]
    @path.gsub! '%u', user
    @path.gsub! '%a', name
    @path
  end

  def host
    return @host if @host
    @host, _ = server.split(':') # Parse host + port
    @host
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

  def current_port
    @current_port ||= port_details[:current_port]
  end

  def current_service
    @current_service ||= port_details[:current_service]
  end

  def former_port
    @former_port ||= port_details[:former_port]
  end

  def former_service
    @former_service ||= port_details[:former_service]
  end

  def current_port_file
    @current_port_file ||= ".foreplay/#{name}/current_port"
  end

  def port_steps
    @port_steps ||= [
      {
        'command' => "mkdir -p .foreplay/#{name} && touch #{current_port_file} && cat #{current_port_file}",
        'silent' => true
      }
    ]
  end

  def port_details
    return @port_details if @port_details

    current_port_string = Foreplay::Engine::Remote.new(server, port_steps, instructions).__send__(mode).strip!

    if current_port_string.blank?
      puts "#{host}#{INDENT}No instance is currently deployed"
    else
      puts "#{host}#{INDENT}Current instance is using port #{current_port_string}"
    end

    cp      = current_port_string.to_i
    port    = instructions[:port]
    ports   = [post + 1000, port]
    cp, fp  = cp == port ? ports : ports.reverse

    @port_details = {
      current_port: cp,
      current_service: "#{name}-#{cp}",
      former_port: fp,
      former_service: "#{name}-#{fp}"
    }
  end
end
