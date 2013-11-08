require 'spec_helper'
require 'foreplay'

describe Foreplay::Deploy do
  before :each do
    `rm config/foreplay.yml`
    `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com -f apps/%a`
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
end
