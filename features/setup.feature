Feature: Setup
  In order to setup Foreplay
  As a CLI user
  I want to be able to create the config scaffold

  Scenario: Setup with defaults
	When I run `foreplay setup`
	Then the output should contain "create  config/foreplay.yml"
	And the following files should exist:
		| config/foreplay.yml |
	And the file "config/foreplay.yml" should contain:
		"""
		defaults:
		  name: aruba
		  repository: %q{TODO: Add the git repository path}
		  user: %q{TODO: Add the user to logon to the deployment server}
		  password: %q{TODO: Add the password for the user on the deployment server}
		  path: %q{TODO: Add the path to deploy to on the deployment server}
		  port: 50000
		production:
		  defaults:
		    database:
		      adapter: postgresql
		      encoding: utf8
		      database: %q{TODO: Add the database name}
		      pool: 5
		      host: %q{TODO: Add the database host name}
		      username: %q{TODO: Add the database user}
		      password: %q{TODO: Add the database user's password}
		  web:
		    servers: [%q{TODO: Add the name of the production web server}]
		    foreman:
		      concurrency: 'web=1,worker=0,scheduler=0'
		"""

  Scenario: Setup invalid short option
	When I run `foreplay setup -x abc`
	Then the following files should not exist:
		| config/foreplay.yml |
	And the output should contain:
		"""
		ERROR: foreplay setup was called with arguments ["-x", "abc"]
		Usage: "foreplay setup".
		"""

  Scenario: Setup invalid option
	When I run `foreplay setup --xyz abc`
	Then the following files should not exist:
		| config/foreplay.yml |
	And the output should contain:
		"""
		ERROR: foreplay setup was called with arguments ["--xyz", "abc"]
		Usage: "foreplay setup".
		"""

  Scenario: Setup invalid pool option type
	When I run `foreplay setup --db_pool abc`
	Then the following files should not exist:
		| config/foreplay.yml |
	And the output should contain:
		"""
		Expected numeric value for '--db-pool'; got "abc"
		"""

  Scenario: Setup invalid port option type
	When I run `foreplay setup --port abc`
	Then the following files should not exist:
		| config/foreplay.yml |
	And the output should contain:
		"""
		Expected numeric value for '--port'; got "abc"
		"""

  Scenario: Setup invalid port short option type
	When I run `foreplay setup -p abc`
	Then the following files should not exist:
		| config/foreplay.yml |
	And the output should contain:
		"""
		Expected numeric value for '--port'; got "abc"
		"""

  Scenario: Setup with short options
	When I run `foreplay setup -n string1 -r string2 -u string3 -p 10000 --password string4 -f string5 -s string6a string6b string6c -a string7 -e string8 -d string9 -h string10 --db_pool 23 --db_user string11 --db_password string12`
	Then the output should contain "create  config/foreplay.yml"
	And the following files should exist:
		| config/foreplay.yml |
	And the file "config/foreplay.yml" should contain:
		"""
		defaults:
		  name: string1
		  repository: string2
		  user: string3
		  password: string4
		  path: string5
		  port: 10000
		production:
		  defaults:
		    database:
		      adapter: string7
		      encoding: string8
		      database: string9
		      pool: 23
		      host: string10
		      username: string11
		      password: string12
		  web:
		    servers: ["string6a", "string6b", "string6c"]
		    foreman:
		      concurrency: 'web=1,worker=0,scheduler=0'
		"""

  Scenario: Setup with short options
	When I run `foreplay setup --name string1 --repository string2 --user string3 --port 10000 --password string4 --path string5 --servers string6a string6b string6c --db_adapter string7 --db_encoding string8 --db_name string9 --db_host string10 --db_pool 23 --db_user string11 --db_password string12`
	Then the output should contain "create  config/foreplay.yml"
	And the following files should exist:
		| config/foreplay.yml |
	And the file "config/foreplay.yml" should contain:
		"""
		defaults:
		  name: string1
		  repository: string2
		  user: string3
		  password: string4
		  path: string5
		  port: 10000
		production:
		  defaults:
		    database:
		      adapter: string7
		      encoding: string8
		      database: string9
		      pool: 23
		      host: string10
		      username: string11
		      password: string12
		  web:
		    servers: ["string6a", "string6b", "string6c"]
		    foreman:
		      concurrency: 'web=1,worker=0,scheduler=0'
		"""
