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

    argument :mode,         type: :string, required: true
    argument :environment,  type: :string, required: true
    argument :filters,      type: :hash,   required: false

    DEFAULTS_KEY  = 'defaults'
    INDENT        = "\t"

    def parse
      # Explain what we're going to do
      message = "#{mode.capitalize}ing #{environment.dup.yellow} environment, "
      message += "#{explanatory_text(filters, 'role')}, #{explanatory_text(filters, 'server')}"
      puts message

      config_file = "#{Dir.getwd}/config/foreplay.yml"

      begin
        config_yml = File.read config_file
      rescue Errno::ENOENT
        terminate "Can't find configuration file #{config_file}.\nPlease run foreplay setup or create the file manually."
      end

      config_all = YAML.load(config_yml)
      config_env = config_all[environment] || {}

      # This environment
      unless config_all.key? environment
        terminate("No deployment configuration defined for #{environment} environment.\nCheck #{config_file}")
      end

      # Servers asked for
      server_filter = filters['server'].split(',') if filters.key?('server')

      # Establish defaults
      # First the default defaults
      defaults = {
        name:         File.basename(Dir.getwd),
        environment:  environment,
        env:          { 'RAILS_ENV' => environment },
        port:         50_000
      }

      defaults = Foreplay::Utility.supermerge(defaults, config_all[DEFAULTS_KEY]) if config_all.key? DEFAULTS_KEY
      defaults = Foreplay::Utility.supermerge(defaults, config_env[DEFAULTS_KEY]) if config_env.key? DEFAULTS_KEY
      threads = []

      config_env.each do |role, additional_instructions|
        next if role == DEFAULTS_KEY # 'defaults' is not a role
        # Only deploy to the role we've specified (or all roles if none is specified)
        next if filters.key?('role') && filters['role'] != role

        instructions        = Foreplay::Utility.supermerge(defaults, additional_instructions).symbolize_keys
        instructions[:role] = role
        required_keys       = [:name, :environment, :role, :servers, :path, :repository]

        required_keys.each do |key|
          next if instructions.key? key
          terminate("Required key #{key} not found in instructions for #{environment} environment.\nCheck #{config_file}")
        end

        # Apply server filter
        instructions[:servers] &= server_filter if server_filter

        threads.concat deploy_role(instructions)
      end

      threads.each(&:join)

      puts mode == :deploy ? 'Finished deployment' : 'Deployment configuration check was successful'
    end

    private

    def deploy_role(instructions)
      servers     = instructions[:servers]
      threads     = []
      preposition = mode == :deploy ? 'to' : 'for'

      if servers.length > 1
        message = "#{mode.capitalize}ing #{instructions[:name].yellow} #{preposition} #{servers.join(', ').yellow} for the "
        message += "#{instructions[:role].dup.yellow} role in the #{environment.dup.yellow} environment..."
        puts message
      end

      servers.each { |server| threads << Thread.new { deploy_to_server server, instructions } }
      threads
    end

    def deploy_to_server(server_port, instructions)
      server, _   = server_port.split(':') # Parse server + port
      name        = instructions[:name]
      role        = instructions[:role]
      path        = instructions[:path]
      repository  = instructions[:repository]
      branch      = instructions[:branch] || 'master'
      user        = instructions[:user]
      port        = instructions[:port]
      preposition = mode == :deploy ? 'to' : 'for'

      message = "#{mode.capitalize}ing #{name.yellow} #{preposition} #{server.yellow} "
      message += "for the #{role.dup.yellow} role in the #{environment.dup.yellow} environment"
      puts message

      # Substitute variables in the path
      path.gsub! '%u', user
      path.gsub! '%a', name

      # Find out which port we're currently running on
      current_port_file = ".foreplay/#{name}/current_port"
      steps = [{ command: "mkdir -p .foreplay/#{name} && touch #{current_port_file} && cat #{current_port_file}", silent: true }]

      current_port_string = execute_on_server(server_port, steps, instructions).strip!

      if current_port_string.blank?
        puts "#{server}#{INDENT}No instance is currently deployed"
      else
        "#{server}#{INDENT}Current instance is using port #{current_port_string}"
      end

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
      current_service = "#{name}-#{current_port}"
      former_service  = "#{name}-#{former_port}"

      instructions[:foreman]['app']   = current_service
      instructions[:foreman]['port']  = current_port
      instructions[:foreman]['user']  = user
      instructions[:foreman]['log']   = "$HOME/#{path}/#{current_port}/log"

      # Contents of .env file
      instructions[:env]['HOME']  = '$HOME'
      instructions[:env]['SHELL'] = '$SHELL'
      instructions[:env]['PATH']  = '$PATH:`which bundle`'

      # Commands to execute on remote server
      steps = [
        {  command:      "echo Foreplay version #{VERSION}",
           commentary:   "Foreplay running from #{`hostname -f`}#{`which foreman`}" },
        {  command:      "mkdir -p #{path} && cd #{path} && rm -rf #{current_port} "\
                         "&& git clone -b #{branch} #{repository} #{current_port}",
           commentary:   "Cloning #{branch} branch of repository #{repository}" },
        {  command:      "rvm rvmrc trust #{current_port}",
           commentary:   'Trusting the .rvmrc file for the new instance' },
        {  command:      "rvm rvmrc warning ignore #{current_port}",
           commentary:   'Ignoring the .rvmrc warning for the new instance' },
        {  command:      'gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys D39DC0E3',
           commentary:   "Trusting RVM's public key" },
        {  command:      "cd #{current_port} && mkdir -p tmp doc log config",
           commentary:   'If you have a .rvmrc file there may be a delay now while we install a new ruby' },
        {  command:      'if [ -f .ruby-version ] ; then rvm install `cat .ruby-version` ; '\
                         'else echo "No .ruby-version file found" ; fi',
           commentary:   'If you have a .ruby-version file there may be a delay now while we install a new ruby' },
        {  key:          :env,
           delimiter:    '=',
           prefix:       '.',
           commentary:   'Building .env' },
        {  key:          :foreman,
           delimiter:    ': ',
           prefix:       '.',
           commentary:   'Building .foreman' },
        {  key:          :database,
           delimiter:    ': ',
           suffix:       '.yml',
           commentary:   'Building config/database.yml',
           before:       '  ',
           header:       "#{environment}:",
           path:         'config/' },
        {  key:          :resque,
           delimiter:    ': ',
           suffix:       '.yml',
           commentary:   'Building config/resque.yml',
           before:       environment,
           path:         'config/' },
        {  command:      'if [ -d ../cache/vendor/bundle/bundle ] ; then rm -rf ../cache/vendor/bundle/bundle'\
                         ' ; else echo No evidence of legacy copy bug ; fi',
           commentary:   'Fixing legacy copy bug' },
        {  command:      'if [ -d ../cache/vendor/bundle ] ; then rsync -aW --no-compress --delete --info=STATS3'\
                         ' ../cache/vendor/bundle/ vendor/bundle ; else echo No bundle to restore ; fi',
           commentary:   'Attempting to restore bundle from cache' },
        {  command:      'sudo ln -f `which bundle` /usr/bin/bundle || echo Using default version of bundle',
           commentary:   'Setting the current version of bundle to be the default' },
        {  command:      'bundle install --deployment --clean --jobs 2 --without development test',
           commentary:   'Using bundler to install the required gems in deployment mode' },
        {  command:      'mkdir -p ../cache/vendor && rsync -aW --no-compress --delete --info=STATS3'\
                         ' vendor/bundle/ ../cache/vendor/bundle',
           commentary:   'Caching bundle' },
        {  command:      'if [ -f public/assets/manifest.yml ] ; then echo "Not precompiling assets"'\
                         " ; else RAILS_ENV=#{environment} bundle exec foreman run rake assets:precompile ; fi",
           commentary:   'Precompiling assets unless they were supplied' },
        {  command:      'sudo bundle exec foreman export upstart /etc/init',
           commentary:   "Converting #{current_service} to an upstart service" },
        {  command:      "sudo start #{current_service} || sudo restart #{current_service}",
           commentary:   'Starting the service',
           ignore_error: true },
        {  command:      "echo #{current_port} > $HOME/#{current_port_file}",
           commentary:   "Setting the port for the new instance to #{current_port}" },
        {  command:      'sleep 60',
           commentary:   'Waiting 60s to give service time to start' },
        {  command:      "sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port #{current_port}",
           commentary:   "Adding firewall rule to direct incoming traffic on port 80 to port #{current_port}" },
        {  command:      "sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port #{former_port}",
           commentary:   "Removing previous firewall rule directing traffic to port #{former_port}",
           ignore_error: true },
        {  command:      'sudo iptables-save > /etc/iptables/rules.v4',
           commentary:   'Attempting to save firewall rules to /etc/iptables/rules.v4',
           ignore_error: true },
        {  command:      'sudo iptables-save > /etc/iptables.up.rules',
           commentary:   'Attempting to save firewall rules to /etc/iptables.up.rules',
           ignore_error: true },
        {  command:      'sudo iptables-save -c | egrep REDIRECT --color=never',
           ignore_error: true,
           commentary:   'Current firewall NAT configuration:' },
        {  command:      "sudo stop #{former_service} || echo 'No previous instance running'",
           commentary:   'Stopping the previous instance',
           ignore_error: true }
      ]

      execute_on_server server_port, steps, instructions
    end

    def execute_on_server(server_port, steps, instructions)
      user        = instructions[:user]
      password    = instructions[:password]
      keyfile     = instructions[:keyfile]
      private_key = instructions[:private_key]

      keyfile.sub! '~', ENV['HOME'] || '/' unless keyfile.blank? # Remote shell won't expand this for us

      server, port = server_port.split(':') # Parse server + port
      port ||= 22

      # SSH authentication methods
      options = { verbose: :warn, port: port }

      if password.blank?
        # If there's no password we must supply a private key
        if private_key.blank?
          message = 'No authentication methods supplied. You must supply a private key, key file or password in the configuration file'
          terminate(message) if keyfile.blank?
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
        puts "#{server}#{INDENT}Connecting to #{server} on port #{port}"

        # SSH connection
        session = start_session(server, server_port, user, options)

        puts "#{server}#{INDENT}Successfully connected to #{server} on port #{port}"

        session.shell do |sh|
          steps.each do |step|
            # Output from this step
            output    = ''
            previous  = '' # We don't need or want the final CRLF
            commands  = build_step server, step, instructions

            commands.each do |command|
              process = sh.execute command

              process.on_output do |_, o|
                previous  = o
                output    += previous
              end

              sh.wait!

              if step[:ignore_error] == true || process.exit_status == 0
                print output.gsub!(/^/, "#{server}#{INDENT * 2}") unless step[:silent] == true || output.blank?
              else
                terminate(output)
              end
            end
          end
        end

        session.close
      else
        # Deployment check: just say what we would have done
        steps.each do |step|
          commands = build_step server, step, instructions

          commands.each { |command| puts "#{server}#{INDENT * 2}#{command}" unless step[:silent] }
        end
      end

      output
    end

    def start_session(server, server_port, user, options)
      Net::SSH.start(server, user, options)
    rescue SocketError => e
      terminate "#{server}#{INDENT}There was a problem starting an ssh session on #{server_port}:\n#{e.message}"
    end

    def build_step(server, step, instructions)
      puts "#{server}#{INDENT}#{(step[:commentary] || step[:command]).yellow}" unless step[:silent] == true

      # Each step can be (1) a command or (2) a series of values to add to a file
      if step.key?(:key)
        if instructions.key?(step[:key])
          build_commands step, instructions
        else
          []
        end
      else
        # ...or just execute the command specified
        [step[:command]]
      end
    end

    def build_commands(step, instructions)
      # Add values from the config file to a file on the remote machine
      key       = step[:key]
      prefix    = step[:prefix]     || ''
      suffix    = step[:suffix]     || ''
      path      = step[:path]       || ''
      before    = step[:before]     || ''
      delimiter = step[:delimiter]  || ''
      after     = step[:after]      || ''

      step[:silent] = true
      filename      = "#{path}#{prefix}#{key}#{suffix}"

      if step.key?(:header)
        commands  = ["echo \"#{step[:header]}\" > #{filename}"]
        redirect  = '>>'
      else
        commands  = []
        redirect  = '>'
      end

      if instructions[key].is_a? Hash
        instructions[key].each do |k, v|
          commands << "echo \"#{before}#{k}#{delimiter}#{v}#{after}\" #{redirect} #{filename}"
          redirect = '>>'
        end
      else
        commands << "echo \"#{before}#{delimiter}#{instructions[key]}#{after}\" #{redirect} #{filename}"
        redirect = '>>'
      end

      commands
    end

    def explanatory_text(hsh, key)
      hsh.key?(key) ? "#{hsh[key].dup.yellow} #{key}" : "all #{key.pluralize}"
    end

    def terminate(message)
      fail message
    end
  end
end
