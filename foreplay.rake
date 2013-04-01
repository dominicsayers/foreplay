# Syntax:
#
#     rake ENV=production [ROLE=web] foreplay:command
#
# You can set the environment variables ENV and ROLE elsewhere if you wish.
# If ROLE is not defined then we deploy all roles.
#
# Dependencies:
#
#    gem 'net-ssh-shell'
#
# You can constrain this to whatever group you use for initiating deployments, e.g.
#
#    group :development do
#      gem 'net-ssh-shell'
#    end

namespace :foreplay do
  desc 'Push app to deployment targets'
  task :push => :environment do
    Foreplay::push
  end

  desc 'Check deployment configuration'
  task :check => :environment do
    Foreplay::push true
  end
end
