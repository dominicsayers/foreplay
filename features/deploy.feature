Feature: deploy
  In order to deploy my app
  From the CLI
  I want to be able to use all features

  Scenario: No arguments
    When I run `foreplay deploy`
    Then the output should contain:
        """
        ERROR: "foreplay deploy" was called with no arguments
        Usage: "foreplay deploy ENVIRONMENT"
        """

  Scenario: invalid parameter
    When I run `foreplay deploy test --invalid xyz`
    Then the output should contain:
    	"""
    	ERROR: "foreplay deploy" was called with arguments ["test", "--invalid", "xyz"]
		  Usage: "foreplay deploy ENVIRONMENT"
    	"""

  Scenario: short invalid parameter
    When I run `foreplay deploy test -x xyz`
    Then the output should contain:
      """
		  ERROR: "foreplay deploy" was called with arguments ["test", "-x", "xyz"]
		  Usage: "foreplay deploy ENVIRONMENT"
    	"""

  Scenario: no config file
    When I run `foreplay deploy test`
    Then the output should contain "Deploying"
      And the output should contain "test environment"
      And the output should contain "all roles"
      And the output should contain "all servers"
      And the output should contain "Can't find configuration file"

  Scenario: deploy all roles
    When I run `foreplay setup`
      And I run `foreplay deploy test`
    Then the output should contain "create  config/foreplay.yml"
      And the output should contain "Deploying"
      And the output should contain "test environment"
      And the output should contain "all roles"
      And the output should contain "all servers"
      And the output should contain "No deployment configuration defined for test environment"
      And the output should not contain "Can't find configuration file"
      And the following files should exist:
        | config/foreplay.yml |

  Scenario: deploy one role
    When I run `foreplay deploy test --role worker`
    Then the output should contain "Deploying"
      And the output should contain "test environment"
      And the output should contain "worker role"
      And the output should contain "all servers"

  Scenario: deploy to one server
    When I run `foreplay deploy test --server worker.example.com`
    Then the output should contain "Deploying"
      And the output should contain "test environment"
      And the output should contain "all roles"
      And the output should contain "worker.example.com server"

  Scenario: deploy to one role - short role parameter
    When I run `foreplay deploy test -r worker`
    Then the output should contain "Deploying"
      And the output should contain "test environment"
      And the output should contain "worker role"
      And the output should contain "all servers"

  Scenario: deployto one server - short server parameter
    When I run `foreplay deploy test -s worker.example.com`
    Then the output should contain "Deploying"
      And the output should contain "test environment"
      And the output should contain "all roles"
      And the output should contain "worker.example.com server"

  Scenario: deploy all roles
    When I run `foreplay setup`
      And I run `foreplay deploy test`
    Then the output should contain "create  config/foreplay.yml"
      And the output should contain "Deploying"
      And the output should contain "test environment"
      And the output should contain "all roles"
      And the output should contain "all servers"
      And the output should not contain "Can't find configuration file"
      And the following files should exist:
        | config/foreplay.yml |

  Scenario: deploy
    When I run `foreplay setup -r git@github.com:Xenapto/foreplay.git -s web.example.com --password "top-secret"`
      And I run `foreplay deploy production`
    Then the output should contain "Deploying aruba to web.example.com for the web role in the production environment"
      And the output should contain "Connecting to web.example.com"
      And the output should contain "There was a problem starting an ssh session on web.example.com"
