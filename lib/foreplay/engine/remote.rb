require 'net/ssh'
require 'pp' # debug

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
      steps.each do |step|
        puts "#{host}#{INDENT}#{(step['commentary'] || step['command']).yellow}" unless step['silent'] == true

        # Output from this step
        output    = ''
        previous  = '' # We don't need or want the final CRLF
        commands  = Foreplay::Engine::Step.new(step, instructions).build

        commands.each do |command|
          process = sh.execute command

          process.on_output do |_, o|
            previous = o
            output += previous
          end

          sh.wait!

          if step['ignore_error'] == true || process.exit_status == 0
            print output.gsub!(/^/, "#{host}#{INDENT * 2}") unless step['silent'] == true || output.blank?
          else
            terminate(output)
          end
        end
      end
    end

    session.close
    output
  end

  # Deployment check: just say what we would have done
  def check
    steps.each do |step|
      puts "#{host}#{INDENT}#{(step['commentary'] || step['command']).yellow}" unless step['silent'] == true

      if step.key? 'key'
        i = instructions[step['key']]

        if i.is_a? Hash
          i.each { |k, v| puts "#{host}#{INDENT * 2}#{k}: #{v}" }
        else
          puts "#{host}#{INDENT * 2}#{i}"
        end
      else
        commands = Foreplay::Engine::Step.new(step, instructions).build

        commands.each do |command|
          puts "#{host}#{INDENT * 2}#{command}" unless step['silent']
        end
      end
    end

    ''
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

    password    = instructions['password']
    keyfile     = instructions['keyfile']
    private_key = instructions['private_key']

    keyfile.sub! '~', ENV['HOME'] || '/' unless keyfile.blank? # Remote shell won't expand this for us

    # SSH authentication methods
    @options = { verbose: :warn, port: port }

    if password.blank?
      # If there's no password we must supply a private key
      if private_key.blank?
        message = 'No authentication methods supplied. '\
                  'You must supply a private key, key file or password in the configuration file'
        terminate(message) if keyfile.blank?
        # Get the key from the key file
        puts "#{INDENT}Using private key from #{keyfile}"
        private_key = File.read keyfile
      else
        puts "#{INDENT}Using private key from the configuration file"
      end

      @options[:key_data] = [private_key]
    else
      # Use the password supplied
      @options[:password] = password
    end

    @options
  end

  def start_session(host, user, options)
    Net::SSH.start(host, user, options)
  rescue SocketError => e
    terminate "#{host}#{INDENT}There was a problem starting an ssh session on #{host}:\n#{e.message}"
  end
end
