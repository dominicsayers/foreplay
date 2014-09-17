require 'spec_helper'
require 'foreplay'
require 'net/ssh/shell'

describe Foreplay::Deploy do
  let(:ssh)      { double(Net::SSH) }
  let(:session)  { double(Net::SSH::Connection::Session) }
  let(:shell)    { double(Net::SSH::Shell) }
  let(:process)  { double(Net::SSH::Shell::Process) }

  before :each do
    # Setup foreplay
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web1.example.com web2.example.com -f apps/%a -u fred --password trollope`

    # Stub all the things
    Net::SSH.stub(:start).and_yield(session)
    session.stub(:shell).and_yield(shell)
    shell.stub(:execute).and_return(process)
    shell.stub(:wait!).and_return(false)
    process.stub(:on_output).and_yield(process, "output message\n")
    process.stub(:exit_status).and_return(0)
  end

  it "should complain on check if there's no config file" do
    `rm -f config/foreplay.yml`
    expect { Foreplay::Deploy.start([:check, 'production', '']) }
      .to raise_error(RuntimeError, /.*Please run foreplay setup or create the file manually.*/)
  end

  it "should complain on deploy if there's no config file" do
    `rm -f config/foreplay.yml`
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }
      .to raise_error(RuntimeError, /.*Please run foreplay setup or create the file manually.*/)
  end

  it 'should complain if there are no authentication methods defined in the config file' do
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a -u fred --password ""`
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }
      .to raise_error(
        RuntimeError,
        /.*No authentication methods supplied. You must supply a private key, key file or password in the configuration file.*/
      )
  end

  it "should complain if the private keyfile defined in the config file doesn't exist" do
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a -u fred --keyfile "/home/fred/no-such-file"`
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }
      .to raise_error(Errno::ENOENT, %r{.*No such file or directory @ rb_sysopen - /home/fred/no-such-file.*})
  end

  it 'complains if a mandatory key is missing from the config file' do
    `sed -i 's/path:/pxth:/' config/foreplay.yml`

    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }
      .to raise_error(
        RuntimeError,
        /.*Required key path not found in instructions for production environment.*/
      )
  end

  it 'complains if we try to deploy an environment that isn\'t defined' do
    expect { Foreplay::Deploy.start([:deploy, 'unknown', '']) }
      .to raise_error(
        RuntimeError,
        /.*No deployment configuration defined for unknown environment.*/
      )
  end

  it 'should terminate if a remote process exits with a non-zero status' do
    process.stub(:exit_status).and_return(1)
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }.to raise_error(RuntimeError, /.*output message.*/)
  end

  it "should terminate if a connection can't be established with the remote server" do
    Net::SSH.unstub(:start)
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }
      .to raise_error(RuntimeError, /.*There was a problem starting an ssh session on web1.example.com.*/)
  end

  it 'should check the config' do
    $stdout.should_receive(:puts).at_least(:once)
    Foreplay::Deploy.start [:check, 'production', '']
  end

  it 'should deploy to the environment' do
    Net::SSH
      .should_receive(:start)
      .with(/web[12].example.com/, 'fred',  verbose: :warn, port: 22, password: 'trollope')
      .exactly(4).times
      .and_yield(session)

    [
      'mkdir -p apps/foreplay && cd apps/foreplay && rm -rf 50000 && git clone -b master git@github.com:Xenapto/foreplay.git 50000',
      'rvm rvmrc trust 50000',
      'rvm rvmrc warning ignore 50000',
      'cd 50000 && mkdir -p tmp doc log config',
      'if [ -f .ruby-version ] ; then rvm install `cat .ruby-version` ; else echo "No .ruby-version file found" ; fi',
      'echo "RAILS_ENV=production" > .env',
      'echo "concurrency: web=1,worker=0,scheduler=0" > .foreman',
      'echo "app: foreplay-50000" >> .foreman',
      'echo "port: 50000" >> .foreman',
      'echo "user: fred" >> .foreman',
      'echo "production:" > config/database.yml',
      'echo "  adapter: postgresql" >> config/database.yml',
      'echo "  encoding: utf8" >> config/database.yml',
      'echo "  database: TODO Put the database name here" >> config/database.yml',
      'echo "  pool: 5" >> config/database.yml',
      'echo "  host: TODO Put here the database host name" >> config/database.yml',
      'echo "  username: TODO Put here the database user" >> config/database.yml',
      'echo "  password: TODO Put here the database user\'s password" >> config/database.yml',
      'if [ -d ../cache/vendor/bundle ] ; then cp -rf ../cache/vendor/bundle vendor/bundle'\
      ' ; else echo No bundle to restore ; fi',
      'sudo ln -f `which bundle` /usr/bin/bundle || echo Using default version of bundle',
      'bundle install --deployment --clean --jobs 2 --without development test',
      'mkdir -p ../cache/vendor && cp -rf vendor/bundle ../cache/vendor/bundle',
      'if [ -f public/assets/manifest.yml ] ; then echo "Not precompiling assets"'\
      ' ; else RAILS_ENV=production bundle exec foreman run rake assets:precompile ; fi',
      'sudo bundle exec foreman export upstart /etc/init',
      'sudo start foreplay-50000 || sudo restart foreplay-50000',
      'mkdir -p .foreplay/foreplay && touch .foreplay/foreplay/current_port && cat .foreplay/foreplay/current_port',
      'echo 50000 > $HOME/.foreplay/foreplay/current_port',
      'sleep 60',
      'sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 50000',
      'sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 51000',
      'sudo iptables-save > /etc/iptables/rules.v4',
      'sudo iptables-save > /etc/iptables.up.rules',
      'sudo iptables-save -c | egrep REDIRECT --color=never',
      'sudo stop foreplay-51000 || echo \'No previous instance running\''
    ].each do |command|
      shell.should_receive(:execute).with(command).and_return(process)
    end

    Foreplay::Deploy.start [:deploy, 'production', '']
  end

  it "should use another port if there's already an installed instance" do
    process.stub(:on_output).and_yield(process, "50000\n")
    shell.should_receive(:execute).with('echo 51000 > $HOME/.foreplay/foreplay/current_port').and_return(process)
    Foreplay::Deploy.start [:deploy, 'production', '']
  end

  it 'should use the private key provided in the config file' do
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a -u fred -k "top secret private key"`
    Foreplay::Deploy.start([:deploy, 'production', ''])
  end

  it 'should add Redis details for Resque' do
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a -u fred --resque-redis "redis://localhost:6379"`
    Foreplay::Deploy.start([:deploy, 'production', ''])
  end
end
