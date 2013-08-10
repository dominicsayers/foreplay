require 'thor/group'
require 'yaml'
require 'net/ssh'
require 'active_support/inflector'
require 'active_support/core_ext/object'
require 'active_support/core_ext/hash'
require 'colorize'

module Foreplay
  class Deploy < Thor::Group
    include Thor::Actions

    argument :mode,         :type => :string, :required => true
    argument :environment,  :type => :string, :required => true
    argument :filters,      :type => :hash

    DEFAULTS_KEY = 'defaults'

    def parse
      # Explain what we're going to do
      puts '%sing %s environment, %s, %s' % [
        mode.capitalize,
        environment.dup.yellow,
        explanatory_text(filters.role, 'role'),
        explanatory_text(filters.server, 'server')
      ]

      config_yml = "#{Dir.getwd}/config/foreplay.yml"
      config_all = YAML.load(File.read(config_yml))
      config_env = config_all[environment]

      # This environment
      terminate("No deployment configuration defined for #{environment} environment.\nCheck #{config_yml}") unless config_all.has_key? environment

      # Establish defaults
      # First the default defaults
      defaults = {
        :name        => File.basename(Dir.getwd),
        :environment => environment,
        :env         => { 'RAILS_ENV' => environment },
        :port        => 50000
      }

      defaults = deep_merge_with_arrays(defaults, config_all[DEFAULTS_KEY])  if config_all.has_key? DEFAULTS_KEY  # Then the global defaults
      defaults = deep_merge_with_arrays(defaults, config_env[DEFAULTS_KEY])  if config_env.has_key? DEFAULTS_KEY  # Then the defaults for this environment

      config_env.each do |role, additional_instructions|
        next if role == DEFAULTS_KEY # 'defaults' is not a role
        next unless filters.role.blank? || filters.role == role # Only deploy to the role we've specified (or all roles if none is specified)

        instructions        = deep_merge_with_arrays(defaults, additional_instructions).symbolize_keys
        instructions[:role] = role
        required_keys       = [:name, :environment, :role, :servers, :path, :repository]

        required_keys.each { |key| terminate("Required key #{key} not found in instructions for #{environment} environment.\nCheck #{config_yml}") unless instructions.has_key? key }

        deploy_role instructions
      end

      puts mode == :deploy ? 'Finished deployment' : 'Deployment configuration check was successful'
    end

    private

    def deploy_role instructions
      servers     = instructions[:servers]
      preposition = mode == :deploy ? 'to' : 'for'

      puts "#{mode.capitalize}ing #{instructions[:name].yellow} #{preposition} #{servers.join(', ').yellow} in the #{instructions[:role].dup.yellow} role on the #{environment.dup.yellow} environment..." if servers.length > 1
      servers.each { |server| deploy_to_server server, instructions }
    end

    def deploy_to_server server, instructions
      name        = instructions[:name]
#      environment = instructions[:environment]
      role        = instructions[:role]
      path        = instructions[:path]
      repository  = instructions[:repository]
      user        = instructions[:user]
      port        = instructions[:port]
      preposition = mode == :deploy ? 'to' : 'for'

      instructions[:server] = server

      puts "#{mode.capitalize}ing #{name.yellow} #{preposition} #{server.yellow} in the #{role.dup.yellow} role on the #{environment.dup.yellow} environment"

      # Substitute variables in the path
      path.sub! '%u', user
      path.sub! '%a', name

      # Find out which port we're currently running on
      steps = [ { :command => 'mkdir -p .foreplay && touch .foreplay/current_port && cat .foreplay/current_port', :silent => true } ]

      current_port = execute_on_server(steps, instructions).strip!
      puts current_port.blank? ? '    No instance is currently deployed' : "    Current instance is using port #{current_port}"

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
        { :command      => "cd #{current_port}",
          :commentary   => 'Configuring the new instance' },
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
        { :command      => "bundle install",
          :commentary   => 'Using bundler to install the required gems' },
        { :command      => "sudo ln -f `which foreman` /usr/bin/foreman",
          :commentary   => 'Setting the current version of foreman to be the default' },
        { :command      => "sudo foreman export upstart /etc/init",
          :commentary   => "Converting #{current_service} to an upstart service" },
        { :command      => "sudo start #{current_service} || sudo restart #{current_service}",
          :commentary   => 'Starting the service',
          :ignore_error => true },
        { :command      => 'sleep 60',
          :commentary   => 'Waiting 60s to give service time to start' },
        { :command      => "sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port #{current_port.to_i + 100}",
          :commentary   => "Adding firewall rule to direct incoming traffic on port 80 to port #{current_port}" },
        { :command      => "sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port #{former_port.to_i + 100}",
          :commentary   => "Removing previous firewall directing traffic to port #{former_port}",
          :ignore_error => true },
        { :command      => "sudo iptables -t nat -L | grep REDIRECT",
          :ignore_error => true,
          :commentary   => "Current firewall NAT configuration:" },
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
      key         = instructions[:key]

      keyfile.sub! '~', ENV['HOME'] || '/' unless keyfile.blank? # Remote shell won't expand this for us

      # SSH authentication methods
      options = { :verbose => :warn }

      if password.blank?
        # If there's no password we must supply a private key
        if key.blank?
          terminate("No authentication methods supplied. You must supply a private key, key file or password in the configuration file") if keyfile.blank?
          # Get the key from the key file
          puts "    Using private key from #{keyfile}"
          key = File.read keyfile
        else
          puts "    Using private key from the configuration file"
        end

        options[:key_data] = [key]
      else
        # Use the password supplied
        options[:password] = password
      end

      # Capture output of last command to return to the calling routine
      output = ''

      if mode == :deploy
        puts "    Connecting to #{server}"

        # SSH connection
        begin
          Net::SSH.start(server, user, options) do |ssh|
            puts "    Successfully connected to #{server}"

            ssh.shell do |sh|
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
                    print output.gsub!(/^/, "        ") unless step[:silent] == true
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

          commands.each { |command| puts "        #{command}" unless step[:silent] }
        end
      end

      output
    end

    def build_commands step, instructions
      puts "    #{(step[:commentary] || step[:command]).yellow}" unless step[:silent] == true

      # Each step can be (1) a command or (2) a series of values to add to a file
      if step.has_key? :key
        step[:silent] = true

        # Add values from the config file to a file on the remote machine
        key       = step[:key]
        prefix    = step[:prefix]     || ''
        suffix    = step[:suffix]     || ''
        path      = step[:path]       || ''
        before    = step[:before]     || ''
        delimiter = step[:delimiter]  || ''
        after     = step[:after]      || ''

        filename  = '%s%s%s%s' % [path, prefix, key, suffix]
        commands  = step.has_key?(:header) ? ['echo "%s" >> %s' % [step[:header], filename]] : []

        instructions[key].each { |k, v| commands << 'echo "%s%s%s%s%s" >> %s' % [before, k, delimiter, v, after, filename] }
      else
        # ...or just execute the command specified
        commands = [step[:command]]
      end
    end

    # Returns a new hash with +hash+ and +other_hash+ merged recursively, including arrays.
    #
    #   h1 = { x: { y: [4,5,6] }, z: [7,8,9] }
    #   h2 = { x: { y: [7,8,9] }, z: 'xyz' }
    #   h1.deep_merge_with_arrays(h2)
    #   #=> {:x=>{:y=>[4, 5, 6, 7, 8, 9]}, :z=>[7, 8, 9, "xyz"]}
    def deep_merge_with_arrays(hash, other_hash)
      new_hash = hash.deep_dup.with_indifferent_access

      other_hash.each_pair do |k,v|
        tv = new_hash[k]

        if tv.is_a?(Hash) && v.is_a?(Hash)
          new_hash[k] = deep_merge_with_arrays(tv, v)
        elsif tv.is_a?(Array) || v.is_a?(Array)
          new_hash[k] = Array.wrap(tv) + Array.wrap(v)
        else
          new_hash[k] = v
        end
      end

      new_hash
    end

    def explanatory_text(value, singular_word)
      value.blank? ? "all #{singular_word.pluralize}" : "#{value.dup.yellow} #{singular_word}"
    end

    def terminate(message)
      puts message.red
      exit!
    end
  end
end
