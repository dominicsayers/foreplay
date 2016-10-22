# Foreplay

![Gem Version](http://img.shields.io/gem/v/foreplay.svg?style=flat)&nbsp;[![Code Climate](http://img.shields.io/codeclimate/github/Xenapto/foreplay.svg?style=flat)](https://codeclimate.com/github/Xenapto/foreplay)&nbsp;[![Coverage Status](https://img.shields.io/coveralls/Xenapto/foreplay.svg?style=flat)](https://coveralls.io/r/Xenapto/foreplay?branch=develop)
[![Dependency Status](https://dependencyci.com/github/Xenapto/foreplay/badge)](https://dependencyci.com/github/Xenapto/foreplay)
[![Developer status](http://img.shields.io/badge/developer-awesome-brightgreen.svg?style=flat)](http://xenapto.com)
![build status](https://circleci.com/gh/Xenapto/foreplay.png?circle-token=dd3a51864d33f6506b18a355bc901b90c0df3b3b) [![Join the chat at https://gitter.im/Xenapto/foreplay](https://badges.gitter.im/Xenapto/foreplay.svg)](https://gitter.im/Xenapto/foreplay?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Deploying Rails projects to Ubuntu using Foreman

I noticed with surprise on [RubyGems](https://rubygems.org/gems/foreplay) that my little gem had been downloaded a few times, so clearly people are trying to use it. Thanks for trying it, people.

There's now a CLI for the gem so you can use it as follows. To check what it's going to do:

    foreplay check production

...and if you're brave enough to try it for real:

    foreplay deploy production

...after you've set it up by creating a `config/foreplay.yml` file.

## Installation

Add this line to your application's Gemfile:

    gem 'foreplay'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install foreplay

### How it works

Foreplay does this:

1.  Opens an SSH connection to the deloyment target
2.  Grabs a copy of your code from the repository
3.  Builds a `.env` file, a `.foreman` file and a `database.yml` file
4.  Does a `bundle install`
5.  Uses `foreman` to create an Upstart service (`foreman export`) for your app
6.  Launches the app
7.  Directs incoming traffic on port 80 to your app
8.  If there's a previous instance of the app running, Foreplay shuts it down gracefully after it has switched `iptables` to the new instance

There should be little or no downtime. If the app is b0rked then you can easily switch back to the previous instance: the Upstart service is still configured.

### foreplay.yml

Here's my actual foreplay.yml that I use to deploy my app Xendata:

```YAML
---
defaults:
  repository: git@github.com:Xenapto/xendata.git
  branch: master
  user: xenapto
  keyfile: ~/.ssh/id_circleci_github
  path: apps/%a
production:
  defaults:
    database:
      adapter: postgresql
      encoding: utf8
      database: xendata
      pool: 10
      host: sandham.xenapto.net
      reconnect: true
      timeout: 5000
      username: kjh123kj1h23
      password: ,mn23-1m412-not-really
    resque: redis://kjjh3425mnb:bn34=-23f2@redis.xenapto.net:6379
  web:
    servers: [sandham.xenapto.net]
    database:
      host: localhost
    foreman:
      concurrency: 'web=1,worker_immediate=2,worker_longjobs=1,scheduler=1,resque_web=1,new_relic_resque=1'
  auxiliary:
    config: ['stop_first'] # It runs out of memory unless I stop the service before asset precompile
    servers: [bradman.xenapto.net,edrich.xenapto.net:10022]
    foreman:
      concurrency: 'worker_regular=8'
  largeserver:
    servers: [simpson.xenapto.net]
    foreman:
      concurrency: 'worker_longjobs=1,worker_regular=24'
```

A quick walk-though of this configuration:

1.  I'm deploying the `master` branch of the Github project `git@github.com:Xenapto/xendata.git`
1.  I'm making an SSH connection to my production servers with the username `xenapto` and the keyfile in `~/.ssh/id_circleci_github` which lives on the machine I'm deploying from
2.  I'm deploying to the directory `~/apps/xendata` (`%a` is expanded to the name of the app)
3.  In this config file I'm defining the `production` environment. I could also define a `staging` section if I wanted to.
3.  On each server I'm creating a `database.yml` file with the contents of the `database` section of this config
4.  I'm creating a `resque.yml` file from the contents of the `resque` section
5.  I'm deploying three different types of server. The roles are `web`, `auxiliary` and `largeserver`. These names are completely arbitrary. I can deploy all or one of these roles.
6.  Each role contains a list of servers and any overrides to the default settings
7.  For instance the `web` role is deployed to `sandham.xenapto.net`. For that server the database is on the same machine (`localhost`). The Foreman `concurrency` setting defines which workers from my Procfile are launched on that server.
8.  Note that in the `auxiliary` role I am deploying to two servers. On the second (`edrich.xenapto.net`) I'm using port 10022 for SSH instead of the default.
9.  Precompiling assets uses a lot of memory. On these servers I get Out Of Memory errors unless I shut down my app first.

General format:

```YAML
defaults:       # global defaults for all environments
  name:         # app name (if omitted then Rails.application.class.parent_name.underscore is used)
  servers: [server1, server2, server3] # which servers to deploy the app on
  user:         # The username to connect with (must have SSH permissions)
  password:     # The password to use to connect (not necessary if you've set up SSH keys)
  keyfile:      # or a file containing a private key that allows the named user access to the server
  key:          # ...or a private key that allows the named user access to the server
  path:         # absolute path to deploy the app on each server. %s will substitute to the app name
  config:       # Configuration parameters to change the behaviour of Foreplay
  database:     # the database.yml elements to write to the config folder
  env:          # contents of the .env file
    key: value  # will go into the .env file as key=value
  foreman:      # contents of the .foreman file
    key: value  # will go into the .foreman file as key: value
production:     # deployment configuration for the production environment
  defaults:     # defaults for all roles in this environment (structure same as global defaults)
  role1:        # settings for the a particular role (e.g. web, worker, etc.)
```

### Environment

Settings for the `.env` files and `.foreman` files in specific sections will add to the defaults specified earlier. `.env` files will get a `RAILS_ENV=environment` entry (where `environment` is as specified in `foreplay.yml`). You can override this by adding a different `RAILS_ENV` setting to this configuration here.

The first instance of the first entry in `Procfile` that is instantiated by your Foreman concurrency settings will
be started on port 50100 or 51100 and the external port 80 will be mapped to this port by `iptables`. You cannot
configure the ports yourself. As an example, if your `Procfile` has a `web` entry on the first line and at
least one `web` instance is configured in the `.foreman` concurrency setting then the first instance of your `web`
process will be available to the outside world on port 80.

### Path

You can use `%u` in the path. This will be substituted with the `user` value. You can use `%a` in the path. This will be substituted with the app's `name`

Example:

    user: fred
    name: myapp
    path: /home/%u/apps/%a

### Dependencies

```ruby
gem 'foreman'
gem 'net-ssh-shell'
```

You can constrain this to whatever groups you use for initiating deployments, e.g.

```ruby
group :development, :test do
  gem 'foreman'
  gem 'net-ssh-shell'
end
```

## Contributing

1.  Fork it
1.  Create your feature branch (`git checkout -b my-new-feature`)
1.  Commit your changes (`git commit -am 'Add some feature'`)
1.  Push to the branch (`git push origin my-new-feature`)
1.  Create new Pull Request

## Acknowledgements

1.  Thanks to Ryan Bigg for the guide to making your first gem https://github.com/radar/guides/blob/master/gem-development.md
