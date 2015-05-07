require 'net/ssh'
require 'net/ssh/shell'

class Foreplay::Engine::Remote
  include Foreplay
  attr_reader :server, :steps, :instructions

  def initialize(s, st, i)
    @server = s
    @steps = st
    @instructions = i
  end

  def deploy
    output = ''

    puts "#{host}#{INDENT}Connecting to #{host} on port #{port}"

    # SSH connection
    session = start_session(host, user, options)

    puts "#{host}#{INDENT}Successfully connected to #{host} on port #{port}"

    session.shell do |sh|
      steps.each { |step| output += Foreplay::Engine::Remote::Step.new(host, sh, step, instructions).execute }
    end

    session.close
    output
  end

  # Deployment check: just say what we would have done
  def check
    Foreplay::Engine::Remote::Check.new(host, steps, instructions).perform
  end

  def user
    @user = instructions['user']
  end

  def host
    @host ||= host_port[0]
  end

  def port
    @port ||= (host_port[1] || 22)
  end

  def host_port
    @host_port ||= server.split(':') # Parse host + port
  end

  def options
    return @options if @options

    @options = { verbose: :warn, port: port }
    password = instructions['password']

    if password.blank?
      @options[:key_data] = [private_key]
    else
      @options[:password] = password
    end

    @options
  end

  def private_key
    pk = instructions['private_key']
    pk.blank? ? private_key_from_file : pk
  end

  def private_key_from_file
    keyfile = instructions['keyfile']
    keyfile.sub! '~', ENV['HOME'] || '/' unless keyfile.blank? # Remote shell won't expand this for us

    terminate(
      'No authentication methods supplied. '\
      'You must supply a private key, key file or password in the configuration file'
    ) if keyfile.blank?

    # Get the key from the key file
    puts "#{INDENT}Using private key from #{keyfile}"
    File.read keyfile
  end

  def start_session(host, user, options)
    Net::SSH.start(host, user, options)
  rescue SocketError => e
    terminate "#{host}#{INDENT}There was a problem starting an ssh session on #{host}:\n#{e.message}"
  end
end
