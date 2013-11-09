require 'spec_helper'
require 'foreplay'
require 'net/ssh/shell'

describe Foreplay::Deploy do
  let (:ssh)      { double(Net::SSH) }
  let (:session)  { double(Net::SSH::Connection::Session) }
  let (:shell)    { double(Net::SSH::Shell) }
  let (:process)  { double(Net::SSH::Shell::Process) }

  before :each do
    # Setup foreplay
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a -u fred --password trollope`

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
    expect { Foreplay::Deploy.start([:check, 'production', '']) }.to raise_error(RuntimeError, /.*Please run foreplay setup or create the file manually.*/)
  end

  it "should complain on deploy if there's no config file" do
    `rm -f config/foreplay.yml`
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }.to raise_error(RuntimeError, /.*Please run foreplay setup or create the file manually.*/)
  end

  it "should complain if there are no authentication methods defined in the config file" do
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a -u fred --password ""`
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }.to raise_error(RuntimeError, /.*No authentication methods supplied. You must supply a private key, key file or password in the configuration file*/)
  end

  it "should complain if the private keyfile defined in the config file doesn't exist" do
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a -u fred --keyfile "/home/fred/no-such-file"`
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }.to raise_error(Errno::ENOENT, /.*No such file or directory - \/home\/fred\/no-such-file*/)
  end

  it "should terminate if a remote process exits with a non-zero status" do
    process.stub(:exit_status).and_return(1)
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }.to raise_error(RuntimeError, /.*output message*/)
  end

  it "should terminate if a connection can't be established with the remote server" do
    Net::SSH.unstub(:start)
    expect { Foreplay::Deploy.start([:deploy, 'production', '']) }.to raise_error(RuntimeError, /.*There was a problem starting an ssh session on web.example.com*/)
  end

	it "should check the config" do
    output = <<OUTPUT
Checking \e[0;33;49mproduction\e[0m environment, all roles, all servers
Checking \e[0;33;49mforeplay\e[0m for \e[0;33;49mweb.example.com\e[0m in the \e[0;33;49mweb\e[0m role on the \e[0;33;49mproduction\e[0m environment
    No instance is currently deployed
    \e[0;33;49mSetting the port for the new instance to 50000\e[0m
        echo 50000 > .foreplay/current_port
    \e[0;33;49mCloning repository git@github.com:Xenapto/foreplay.git\e[0m
        mkdir -p apps/foreplay && cd apps/foreplay && rm -rf 50000 && git clone git@github.com:Xenapto/foreplay.git 50000
    \e[0;33;49mTrusting the .rvmrc file for the new instance\e[0m
        rvm rvmrc trust 50000
    \e[0;33;49mConfiguring the new instance\e[0m
        cd 50000
    \e[0;33;49mBuilding .env\e[0m
    \e[0;33;49mBuilding .foreman\e[0m
    \e[0;33;49mBuilding config/database.yml\e[0m
    \e[0;33;49mUsing bundler to install the required gems\e[0m
        bundle install
    \e[0;33;49mSetting the current version of foreman to be the default\e[0m
        sudo ln -f `which foreman` /usr/bin/foreman
    \e[0;33;49mConverting foreplay-50000 to an upstart service\e[0m
        sudo foreman export upstart /etc/init
    \e[0;33;49mStarting the service\e[0m
        sudo start foreplay-50000 || sudo restart foreplay-50000
    \e[0;33;49mWaiting 60s to give service time to start\e[0m
        sleep 60
    \e[0;33;49mAdding firewall rule to direct incoming traffic on port 80 to port 50000\e[0m
        sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 50100
    \e[0;33;49mRemoving previous firewall directing traffic to port 51000\e[0m
        sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 51100
    \e[0;33;49mSaving iptables rules to /etc/iptables/rules.v4\e[0m
        sudo iptables-save > /etc/iptables/rules.v4
    \e[0;33;49mSaving iptables rules to /etc/iptables.up.rules\e[0m
        sudo iptables-save > /etc/iptables.up.rules
    \e[0;33;49mCurrent firewall NAT configuration:\e[0m
        sudo iptables-save -c | egrep REDIRECT --color=never
    \e[0;33;49mStopping the previous instance\e[0m
        sudo stop foreplay-51000 || echo 'No previous instance running'
Deployment configuration check was successful
OUTPUT

    output.split("\n").reverse.each { |line| $stdout.should_receive(:puts).with(line) }
		Foreplay::Deploy.start [:check, 'production', '']
	end

  it "should deploy to the environment" do
    Net::SSH.should_receive(:start).with('web.example.com', 'fred', { :verbose => :warn, :password => 'trollope' }).and_yield(session)

    [
      'mkdir -p .foreplay && touch .foreplay/current_port && cat .foreplay/current_port',
      'echo 50000 > .foreplay/current_port',
      'mkdir -p apps/foreplay && cd apps/foreplay && rm -rf 50000 && git clone git@github.com:Xenapto/foreplay.git 50000',
      'rvm rvmrc trust 50000',
      'cd 50000',
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
      'bundle install',
      'sudo ln -f `which foreman` /usr/bin/foreman',
      'sudo foreman export upstart /etc/init',
      'sudo start foreplay-50000 || sudo restart foreplay-50000',
      'sleep 60',
      'sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 50100',
      'sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 51100',
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
    shell.should_receive(:execute).with('echo 51000 > .foreplay/current_port').and_return(process)
    Foreplay::Deploy.start [:deploy, 'production', '']
  end

  it "should use the private key provided in the config file" do
    `rm -f config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a -u fred -k "top secret private key"`
    Foreplay::Deploy.start([:deploy, 'production', ''])
  end
end
