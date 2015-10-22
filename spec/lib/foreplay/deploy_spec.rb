require 'net/ssh/shell'

describe Foreplay::Launcher do
  let(:session) { double(Net::SSH::Connection::Session) }
  let(:shell)   { double(Net::SSH::Shell) }
  let(:process) { double(Net::SSH::Shell::Process) }

  before :each do
    # Setup foreplay
    `rm -f config/foreplay.yml`
    command = 'foreplay setup '\
              '-r git@github.com:Xenapto/foreplay.git '\
              '-s web1.example.com web2.example.com '\
              '-f apps/%a '\
              '-u fred '\
              '--password trollope'
    `#{command}`

    # Stub all the things
    allow(Net::SSH).to receive(:start).and_return(session)
    allow(session).to receive(:close)
    allow(session).to receive(:shell).and_yield(shell)
    allow(shell).to receive(:execute).and_return(process)
    allow(shell).to receive(:wait!).and_return(false)
    allow(process).to receive(:on_output).and_yield(process, "output message 1\noutput message 2\n")
    allow(process).to receive(:exit_status).and_return(0)
  end

  it "complains on check if there's no config file" do
    `rm -f config/foreplay.yml`
    expect { Foreplay::Launcher.start([:check, 'production', '']) }
      .to raise_error(RuntimeError, /.*Please run foreplay setup or create the file manually.*/)
  end

  it "complains on deploy if there's no config file" do
    `rm -f config/foreplay.yml`
    expect { Foreplay::Launcher.start([:deploy, 'production', '']) }
      .to raise_error(RuntimeError, /.*Please run foreplay setup or create the file manually.*/)
  end

  it 'complains on check if the config file is not valid YAML' do
    `echo %*:*: > config/foreplay.yml`
    expect { Foreplay::Launcher.start([:check, 'production', '']) }
      .to raise_error(RuntimeError, /.*Please run foreplay setup or edit the file manually.*/)
  end

  it 'complains on deploy if the config file is not valid YAML' do
    `echo %*:*: > config/foreplay.yml`
    expect { Foreplay::Launcher.start([:deploy, 'production', '']) }
      .to raise_error(RuntimeError, /.*Please run foreplay setup or edit the file manually.*/)
  end

  it 'complains if there are no authentication methods defined in the config file' do
    command = 'foreplay setup '\
              '-r git@github.com:Xenapto/foreplay.git '\
              '-s web.example.com '\
              '-f apps/%a '\
              '-u fred '\
              '--password ""'

    match = 'No authentication methods supplied. '\
            'You must supply a private key, key file or password in the configuration file.'

    `rm -f config/foreplay.yml`
    `#{command}`

    expect { Foreplay::Launcher.start([:deploy, 'production', '']) }
      .to raise_error(
        RuntimeError,
        /.*#{Regexp.quote(match)}*/
      )
  end

  it "complains if the private keyfile defined in the config file doesn't exist" do
    command = 'foreplay setup '\
              '-r git@github.com:Xenapto/foreplay.git '\
              '-s web.example.com '\
              '-f apps/%a '\
              '-u fred '\
              '--keyfile "/home/fred/no-such-file"'

    `rm -f config/foreplay.yml`
    `#{command}`

    # Exact error message text is Ruby version dependent
    expect { Foreplay::Launcher.start([:deploy, 'production', '']) }
      .to raise_error(Errno::ENOENT, %r{.*No such file or directory.+/home/fred/no-such-file.*})
  end

  it 'complains if a mandatory key is missing from the config file' do
    `sed -i 's/path:/pxth:/' config/foreplay.yml`

    expect { Foreplay::Launcher.start([:deploy, 'production', '']) }
      .to raise_error(
        RuntimeError,
        /.*Required key path not found in instructions for production environment.*/
      )
  end

  it 'complains if we try to deploy an environment that isn\'t defined' do
    expect { Foreplay::Launcher.start([:deploy, 'unknown', '']) }
      .to raise_error(
        RuntimeError,
        /.*No deployment configuration defined for unknown environment.*/
      )
  end

  it 'terminates if a remote process exits with a non-zero status' do
    allow(process).to receive(:exit_status).and_return(1)
    expect { Foreplay::Launcher.start([:deploy, 'production', '']) }.to raise_error(RuntimeError, /.*output message.*/)
  end

  it "terminates if a connection can't be established with the remote server" do
    allow(Net::SSH).to receive(:start).and_call_original
    expect { Foreplay::Launcher.start([:deploy, 'production', '']) }
      .to raise_error(RuntimeError, /.*There was a problem starting an ssh session on web1.example.com.*/)
  end

  it 'checks the config' do
    expect($stdout).to receive(:puts).at_least(:once)
    Foreplay::Launcher.start [:check, 'production', '']
  end

  it 'deploys to the environment' do
    secret_data = { 'BIG_SECRET' => '123', 'MOUSTACHE' => '{{moustache}}' }
    secrets = double(Foreplay::Engine::Secrets)
    allow(secrets).to receive(:fetch).and_return(secret_data)
    allow(Foreplay::Engine::Secrets).to receive(:new).and_return(secrets)

    expect(Net::SSH)
      .to(receive(:start))
      .with(/web[12].example.com/, 'fred',  verbose: :warn, port: 22, password: 'trollope')
      .exactly(4).times
      .and_return(session)

    [
      "echo Foreplay version #{Foreplay::VERSION}",
      'mkdir -p apps/foreplay && cd apps/foreplay && rm -rf 50000 && '\
      'git clone -b master git@github.com:Xenapto/foreplay.git 50000',
      'rvm rvmrc trust 50000',
      'rvm rvmrc warning ignore 50000',
      'gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys D39DC0E3',
      'cd 50000 && mkdir -p tmp doc log config',
      'rvm rvmrc load && rvm info',
      'if [ -f .ruby-version ] ; then rvm install `cat .ruby-version` ; else echo "No .ruby-version file found" ; fi',
      'echo "BIG_SECRET=123" > .env',
      'echo "MOUSTACHE={{moustache}}" >> .env',
      'echo "HOME=$HOME" >> .env',
      'echo "SHELL=$SHELL" >> .env',
      'echo "PATH=$PATH:`which bundle`" >> .env',
      'echo "GEM_HOME=$HOME/.rvm/gems/`rvm tools identifier`" >> .env',
      'echo "RAILS_ENV=production" >> .env',
      'echo "---" > config/application.yml',
      'echo "production:" >> config/application.yml',
      'echo "  BIG_SECRET: \'123\'" >> config/application.yml',
      'echo "  MOUSTACHE: ! \'{{moustache}}\'" >> config/application.yml',
      'echo "---" > .foreman',
      'echo "concurrency: web=1,worker=0,scheduler=0" >> .foreman',
      'echo "app: foreplay-50000" >> .foreman',
      'echo "port: 50000" >> .foreman',
      'echo "user: fred" >> .foreman',
      'echo "---" > config/database.yml',
      'echo "production:" >> config/database.yml',
      'echo "  adapter: postgresql" >> config/database.yml',
      'echo "  encoding: utf8" >> config/database.yml',
      'echo "  database: TODO Put the database name here" >> config/database.yml',
      'echo "  pool: 5" >> config/database.yml',
      'echo "  host: TODO Put here the database host name" >> config/database.yml',
      'echo "  username: TODO Put here the database user" >> config/database.yml',
      'echo "  password: TODO Put here the database user\'s password" >> config/database.yml',
      'if [ -d ../cache/vendor/bundle ] ; then '\
      'rsync -aW --no-compress --delete --info=STATS1 ../cache/vendor/bundle/ vendor/bundle'\
      ' ; else echo No bundle to restore ; fi',
      'gem install bundler -v "> 1.8"',
      'sudo ln -f `which bundle` /usr/bin/bundle || echo Using default version of bundle',
      '/usr/bin/bundle install --deployment --clean --jobs 2 --without development test',
      'mkdir -p ../cache/vendor && '\
      'rsync -aW --no-compress --delete --info=STATS1 vendor/bundle/ ../cache/vendor/bundle',
      'if [ -f public/assets/manifest.yml ] ; then echo "Not precompiling assets"'\
      ' ; else RAILS_ENV=production /usr/bin/bundle exec foreman run rake assets:precompile ; fi',
      'sudo /usr/bin/bundle exec foreman export upstart /etc/init',
      'sudo start foreplay-50000 || sudo restart foreplay-50000',
      'mkdir -p .foreplay/foreplay && touch .foreplay/foreplay/current_port && cat .foreplay/foreplay/current_port',
      'echo 50000 > $HOME/.foreplay/foreplay/current_port',
      'sleep 60',
      'sudo stop foreplay-51000 || echo \'No previous instance running\''
    ].each do |command|
      expect(shell).to receive(:execute).with(command).and_return(process)
    end

    Foreplay::Launcher.start [:deploy, 'production', '']
  end

  it "uses another port if there's already an installed instance" do
    allow(process).to receive(:on_output).and_yield(process, "50000\n")
    expect(shell).to receive(:execute).with('echo 51000 > $HOME/.foreplay/foreplay/current_port').and_return(process)
    Foreplay::Launcher.start [:deploy, 'production', '']
  end

  it 'uses the private key provided in the config file' do
    command = 'foreplay setup '\
              '-r git@github.com:Xenapto/foreplay.git '\
              '-s web.example.com '\
              '-f apps/%a '\
              '-u fred '\
              '-k "top secret private key"'

    `rm -f config/foreplay.yml`
    `#{command}`
    Foreplay::Launcher.start([:deploy, 'production', ''])
  end

  it 'adds Redis details for Resque' do
    command = 'foreplay setup '\
              '-r git@github.com:Xenapto/foreplay.git '\
              '-s web.example.com '\
              '-f apps/%a '\
              '-u fred '\
              '--resque-redis "redis://localhost:6379"'

    `rm -f config/foreplay.yml`
    `#{command}`
    Foreplay::Launcher.start([:deploy, 'production', ''])
  end
end
