# encoding: utf-8
require 'yaml'
require 'net/ssh'

class Foreplay
  class << self
    def push check_only = false
      environment = ENV['ENV']
      config_file = "#{Rails.root}/config/foreplay.yml"
      config_all  = YAML.load(File.read(config_file))

      # This environment
      raise RuntimeError, "No deployment environment defined. Set the ENV environment variable." if environment.blank?
      raise RuntimeError, "No deployment configuration defined for #{environment} environment. Check #{config_file}" unless config_all.has_key? environment
      config = config_all[environment]

      # Establish defaults
      # First the default defaults
      defaults = {
        'name'        => Rails.application.class.parent_name.underscore,
        'environment' => environment,
        'env'         => { 'RAILS_ENV' => environment }
      }

      defaults = deep_merge_with_arrays(defaults, config_all['defaults'])  if config_all.has_key? 'defaults'  # Then the global defaults
      defaults = deep_merge_with_arrays(defaults, config['defaults'])      if config.has_key? 'defaults'      # Then the defaults for this environment

      config.each do |role, additional_instructions|
        next if role == 'defaults' # 'defaults' is not a role
        next unless ENV['ROLE'].blank? || ENV['ROLE'] == role # Only deploy to the role we've specified (or all roles if none is specified)

        instructions        = deep_merge_with_arrays(defaults, additional_instructions).symbolize_keys
        instructions[:role] = role
        required_keys       = [:name, :environment, :role, :servers, :path, :repository]

        required_keys.each { |key| raise RuntimeError, "Required key #{key} not found in instructions for #{environment} environment. Check #{config_file}" unless instructions.has_key? key }

        deploy_role instructions unless check_only
      end

      puts check_only ? 'Deployment configuration check was successful' : 'Finished deployment'
    end

    def deploy_role instructions
      servers = instructions[:servers]
      puts "Deploying #{instructions[:name]} to #{servers.join(', ')} for the #{instructions[:role]} role in the #{instructions[:environment]} environment..." if servers.length > 1
      servers.each { |server| deploy_to_server server, instructions }
    end

    def deploy_to_server server, instructions
      name        = instructions[:name]
      environment = instructions[:environment]
      role        = instructions[:role]
      path        = instructions[:path]
      repository  = instructions[:repository]
      user        = instructions[:user]

      instructions[:server] = server

      puts "Deploying #{name} to #{server} for the #{role} role in the #{environment} environment"

      # Substitute variables in the path
      path.sub! '%u', user
      path.sub! '%a', name

      # Find out which port we're currently running on
      steps = [ { :command => 'mkdir -p .foreplay && touch .foreplay/current_port && cat .foreplay/current_port', :silent => true } ]

      current_port = execute_on_server(steps, instructions).strip!
      puts "Current instance is using port #{current_port}"

      # Switch ports
      if current_port == '50000'
        current_port  = '51000'
        former_port   = '50000'
      else
        current_port  = '50000'
        former_port   = '51000'
      end

      # Contents of .foreman file
      current_service = '%s-%s' % [name, current_port]
      former_service  = '%s-%s' % [name, former_port]

      instructions[:foreman]['app']   = current_service
      instructions[:foreman]['port']  = current_port
      instructions[:foreman]['user']  = user

      # Commands to execute on remote server
      steps = [
        { :command      => "echo #{current_port} > .foreplay/current_port" },
        { :command      => "mkdir -p #{path} && cd #{path} && rm -rf #{current_port} && git clone #{repository} #{current_port}",
          :commentary   => "Cloning repository #{repository}" },
        { :command      => "rvm rvmrc trust #{current_port}" },
        { :command      => "cd #{current_port}" },
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
        { :command      => "bundle install" },
        { :command      => "sudo ln -f `which foreman` /usr/bin/foreman" },
        { :command      => "sudo foreman export upstart /etc/init" },
        { :command      => "sudo start #{current_service} || sudo restart #{current_service}",
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

      keyfile.sub! '~' , ENV['HOME'] # Remote shell won't expand this for us

      # SSH authentication methods
      options = { :verbose => :warn }

      if password.blank?
        # If there's no password we must supply a private key
        if key.blank?
          raise RuntimeError, "No authentication methods supplied. You must supply a private key, key file or password in the configuration file" if keyfile.blank?
          # Get the key from the key file
          puts "Using private key from #{keyfile}"
          key = File.read keyfile
        else
          puts "Using private key from the configuration file"
        end

        options[:key_data] = [key]
      else
        # Use the password supplied
        options[:password] = password
      end

      # Capture output of last command to return to the calling routine
      output = ''

      # SSH connection
      Net::SSH.start(server, user, options) do |ssh|
        puts "Successfully connected to #{server}"

        ssh.shell do |sh|
          steps.each do |step|
            # Output from this step
            output    = ''
            previous  = '' # We don't need or want the final CRLF

            puts step[:commentary] || step[:command] unless step[:silent] == true

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

            commands.each do |command|
              process = sh.execute command

              process.on_output do |p, o|
                previous  = o
                output    += previous
              end

              sh.wait!

              if step[:ignore_error] == true || process.exit_status == 0
                print "#{output}" unless step[:silent] == true
              else
                raise RuntimeError, output
              end
            end
          end
        end
      end

      output
    end

    # Returns a new hash with +hash+ and +other_hash+ merged recursively, including arrays.
    #
    #   h1 = { x: { y: [4,5,6] }, z: [7,8,9] }
    #   h2 = { x: { y: [7,8,9] }, z: 'xyz' }
    #   h1.deep_merge_with_arrays(h2)
    #   #=> {:x=>{:y=>[4, 5, 6, 7, 8, 9]}, :z=>[7, 8, 9, "xyz"]}
    def deep_merge_with_arrays(hash, other_hash)
      new_hash = hash.deep_dup

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
  end
end