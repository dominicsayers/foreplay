require 'thor/group'
require 'yaml'
require 'net/ssh'
require 'net/ssh/shell'
require 'active_support/inflector'
require 'active_support/core_ext/object'
require 'active_support/core_ext/hash'
require 'colorize'
require 'foreplay/utility'

module Foreplay
  class Deploy < Thor::Group
    include Thor::Actions

    argument :mode,         :type => :string, :required => true
    argument :environment,  :type => :string, :required => true
    argument :filters,      :type => :hash,   :required => false

    DEFAULTS_KEY  = 'defaults'
    INDENT        = ' ' * 4

    def parse
      # Explain what we're going to do
      puts '%sing %s environment, %s, %s' % [
        mode.capitalize,
        environment.dup.yellow,
        explanatory_text(filters, 'role'),
        explanatory_text(filters, 'server')
      ]

      config_file = "#{Dir.getwd}/config/foreplay.yml"

      begin
        config_yml = File.read config_file
      rescue Errno::ENOENT
        terminate "Can't find configuration file #{config_file}.\nPlease run foreplay setup or create the file manually."
      end

      config_all = YAML.load(config_yml)
      config_env = config_all[environment] || {}

      # This environment
      terminate("No deployment configuration defined for #{environment} environment.\nCheck #{config_file}") unless config_all.has_key? environment

      # Establish defaults
      # First the default defaults
      defaults = {
        :name        => File.basename(Dir.getwd),
        :environment => environment,
        :env         => { 'RAILS_ENV' => environment },
        :port        => 50000
      }

      defaults = Foreplay::Utility::supermerge(defaults, config_all[DEFAULTS_KEY])  if config_all.has_key? DEFAULTS_KEY  # Then the global defaults
      defaults = Foreplay::Utility::supermerge(defaults, config_env[DEFAULTS_KEY])  if config_env.has_key? DEFAULTS_KEY  # Then the defaults for this environment

      config_env.each do |role, additional_instructions|
        next if role == DEFAULTS_KEY # 'defaults' is not a role
        next if filters.has_key?('role') && filters['role'] != role # Only deploy to the role we've specified (or all roles if none is specified)

        instructions        = Foreplay::Utility::supermerge(defaults, additional_instructions).symbolize_keys
        instructions[:role] = role
        required_keys       = [:name, :environment, :role, :servers, :path, :repository]
        required_keys.each { |key| terminate("Required key #{key} not found in instructions for #{environment} environment.\nCheck #{config_file}") unless instructions.has_key? key }

        deploy_role instructions
      end

      puts mode == :deploy ? 'Finished deployment' : 'Deployment configuration check was successful'
    end

    private

    def deploy_role instructions
      servers     = instructions[:servers]
      preposition = mode == :deploy ? 'to' : 'for'

      puts "#{mode.capitalize}ing #{instructions[:name].yellow} #{preposition} #{servers.join(', ').yellow} for the #{instructions[:role].dup.yellow} role in the #{environment.dup.yellow} environment..." if servers.length > 1
      servers.each { |server| deploy_to_server server, instructions }
    end

    def deploy_to_server server, instructions
      name        = instructions[:name]
      role        = instructions[:role]
      path        = instructions[:path]
      repository  = instructions[:repository]
      user        = instructions[:user]
      port        = instructions[:port]
      preposition = mode == :deploy ? 'to' : 'for'

      instructions[:server] = server

      puts "#{mode.capitalize}ing #{name.yellow} #{preposition} #{server.yellow} for the #{role.dup.yellow} role in the #{environment.dup.yellow} environment"

      # Substitute variables in the path
      path.gsub! '%u', user
      path.gsub! '%a', name

      # Find out which port we're currently running on
      steps = [ { :command => 'mkdir -p .foreplay && touch .foreplay/current_port && cat .foreplay/current_port', :silent => true } ]

      current_port_string = execute_on_server(steps, instructions).strip!
      puts current_port_string.blank? ? "#{INDENT}No instance is currently deployed" : "#{INDENT}Current instance is using port #{current_port_string}"

      current_port = current_port_string.to_i

      # Switch ports
      if current_port == port
        current_port  = port + 1000
        former_port   = port
      else
        current_port  = port
        former_port   = port + 1000
      end

      # Contents of .foreman file
      current_service = '%s-%s' % [name, current_port]
      former_service  = '%s-%s' % [name, former_port]

      instructions[:foreman]['app']   = current_service
      instructions[:foreman]['port']  = current_port
      instructions[:foreman]['user']  = user

      # Commands to execute on remote server
      steps = [
        { :command      => "echo #{current_port} > .foreplay/current_port",
          :commentary   => "Setting the port for the new instance to #{current_port}" },
        { :command      => "mkdir -p #{path} && cd #{path} && rm -rf #{current_port} && git clone #{repository} #{current_port}",
          :commentary   => "Cloning repository #{repository}" },
        { :command      => "rvm rvmrc trust #{current_port}",
          :commentary   => 'Trusting the .rvmrc file for the new instance' },
        { :command      => "rvm rvmrc warning ignore #{current_port}",
          :commentary   => 'Ignoring the .rvmrc warning for the new instance' },
        { :command      => "cd #{current_port}",
          :commentary   => 'If you have a .rvmrc file there may be a delay now while we install a new ruby' },
        { :command      => 'if [ -f .ruby-version ] ; then rvm install `cat .ruby-version` ; else echo "No .ruby-version file found" ; fi',
          :commentary   => 'If you have a .ruby-version file there may be a delay now while we install a new ruby' },
        { :command      => 'mkdir -p config',
          :commentary   => "Making sure the config directory exists" },
        { :key          => :env,
          :delimiter    => '=',
          :prefix       => '.',
          :commentary   => 'Building .env' },
        { :key          => :foreman,
          :delimiter    => ': ',
          :prefix       => '.',
          :commentary   => 'Building .foreman' },
        { :key          => :database,
          :delimiter    => ': ',
          :suffix       => '.yml',
          :commentary   => 'Building config/database.yml',
          :before       => '  ',
          :header       => "#{environment}:",
          :path         => 'config/' },
        { :command      => 'bundle install --deployment --without development test',
          :commentary   => 'Using bundler to install the required gems in deployment mode' },
        { :command      => 'sudo ln -f `which foreman` /usr/bin/foreman',
          :commentary   => 'Setting the current version of foreman to be the default' },
        { :command      => 'sudo foreman export upstart /etc/init',
          :commentary   => "Converting #{current_service} to an upstart service" },
        { :command      => "sudo start #{current_service} || sudo restart #{current_service}",
          :commentary   => 'Starting the service',
          :ignore_error => true },
        { :command      => 'sleep 60',
          :commentary   => 'Waiting 60s to give service time to start' },
        { :command      => "sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port #{current_port}",
          :commentary   => "Adding firewall rule to direct incoming traffic on port 80 to port #{current_port}" },
        { :command      => "sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port #{former_port}",
          :commentary   => "Removing previous firewall rule directing traffic to port #{former_port}",
          :ignore_error => true },
        { :command      => 'sudo iptables-save > /etc/iptables/rules.v4',
          :commentary   => 'Attempting to save firewall rules to /etc/iptables/rules.v4',
          :ignore_error => true },
        { :command      => 'sudo iptables-save > /etc/iptables.up.rules',
          :commentary   => 'Attempting to save firewall rules to /etc/iptables.up.rules',
          :ignore_error => true },
        { :command      => 'sudo iptables-save -c | egrep REDIRECT --color=never',
          :ignore_error => true,
          :commentary   => 'Current firewall NAT configuration:' },
        { :command      => "sudo stop #{former_service} || echo 'No previous instance running'",
          :commentary   => 'Stopping the previous instance',
          :ignore_error => true },
      ]

      execute_on_server steps, instructions
    end

    def execute_on_server steps, instructions
      server      = instructions[:server]
      user        = instructions[:user]
      password    = instructions[:password]
      keyfile     = instructions[:keyfile]
      private_key = instructions[:private_key]

      keyfile.sub! '~', ENV['HOME'] || '/' unless keyfile.blank? # Remote shell won't expand this for us

      # SSH authentication methods
      options = { :verbose => :warn }

      if password.blank?
        # If there's no password we must supply a private key
        if private_key.blank?
          terminate('No authentication methods supplied. You must supply a private key, key file or password in the configuration file') if keyfile.blank?
          # Get the key from the key file
          puts "#{INDENT}Using private key from #{keyfile}"
          private_key = File.read keyfile
        else
          puts "#{INDENT}Using private key from the configuration file"
        end

        options[:key_data] = [private_key]
      else
        # Use the password supplied
        options[:password] = password
      end

      # Capture output of last command to return to the calling routine
      output = ''

      if mode == :deploy
        puts "#{INDENT}Connecting to #{server}"

        # SSH connection
        begin
          Net::SSH.start(server, user, options) do |session|
            puts "#{INDENT}Successfully connected to #{server}"

            session.shell do |sh|
              steps.each do |step|
                # Output from this step
                output    = ''
                previous  = '' # We don't need or want the final CRLF

                commands = build_commands step, instructions

                commands.each do |command|
                  process = sh.execute command

                  process.on_output do |p, o|
                    previous  = o
                    output    += previous
                  end

                  sh.wait!

                  if step[:ignore_error] == true || process.exit_status == 0
                    print output.gsub!(/^/, INDENT * 2) unless step[:silent] == true || output.blank?
                  else
                    terminate(output)
                  end
                end
              end
            end
          end
        rescue SocketError => e
          terminate "There was a problem starting an ssh session on #{server}:\n#{e.message}"
        end
      else
        # Deployment check: just say what we would have done
        steps.each do |step|
          commands = build_commands step, instructions

          commands.each { |command| puts "#{INDENT * 2}#{command}" unless step[:silent] }
        end
      end

      output
    end

    def build_commands step, instructions
      puts "#{INDENT}#{(step[:commentary] || step[:command]).yellow}" unless step[:silent] == true

      # Each step can be (1) a command or (2) a series of values to add to a file
      if step.has_key? :key
        # Add values from the config file to a file on the remote machine
        key       = step[:key]
        prefix    = step[:prefix]     || ''
        suffix    = step[:suffix]     || ''
        path      = step[:path]       || ''
        before    = step[:before]     || ''
        delimiter = step[:delimiter]  || ''
        after     = step[:after]      || ''

        step[:silent] = true
        filename      = '%s%s%s%s' % [path, prefix, key, suffix]

        if step.has_key?(:header)
          commands  = ['echo "%s" > %s' % [step[:header], filename]]
          redirect  = '>>'
        else
          commands  = []
          redirect  = '>'
        end

        instructions[key].each do |k, v|
          commands << 'echo "%s%s%s%s%s" %s %s' % [before, k, delimiter, v, after, redirect, filename]
          redirect = '>>'
        end

        commands
      else
        # ...or just execute the command specified
        [step[:command]]
      end
    end

    def explanatory_text(hsh, key)
      hsh.has_key?(key) ? "#{hsh[key].dup.yellow} #{key}" : "all #{key.pluralize}"
    end

    def terminate(message)
      raise message
    end
  end
end
