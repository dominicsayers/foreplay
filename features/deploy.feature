Feature: Deploy
  In order to use Foreplay
  From the CLI
  I want to be able to access all features

  Scenario: Check configuration
    When I run `foreplay check`
    Then the output should contain:
        """
        ERROR: foreplay check was called with no arguments
        Usage: "foreplay check ENVIRONMENT".
        """

  Scenario: Check configuration parameters - invalid parameter
    When I run `foreplay check production --invalid xyz`
    Then the output should contain:
    	"""
    	ERROR: foreplay check was called with arguments ["production", "--invalid", "xyz"]
		  Usage: "foreplay check ENVIRONMENT".
    	"""

  Scenario: Check configuration parameters - short invalid parameter
    When I run `foreplay check production -x xyz`
    Then the output should contain:
      """
		  ERROR: foreplay check was called with arguments ["production", "-x", "xyz"]
		  Usage: "foreplay check ENVIRONMENT".
    	"""

  Scenario: Check configuration parameters - no config file
    When I run `foreplay check production`
    Then the output should contain "Checking"
      And the output should contain "production environment"
      And the output should contain "all roles"
      And the output should contain "all servers"
      And the output should contain "Can't find configuration file"

  Scenario: Check configuration parameters
    When I run `foreplay setup`
      And I run `foreplay check production`
    Then the output should contain "create  config/foreplay.yml"
      And the output should contain "Checking"
      And the output should contain "production environment"
      And the output should contain "all roles"
      And the output should contain "all servers"
      And the output should not contain "Can't find configuration file"
      And the following files should exist:
        | config/foreplay.yml |

  Scenario: Check configuration parameters - role parameter
    When I run `foreplay check production --role worker`
    Then the output should contain "Checking"
      And the output should contain "production environment"
      And the output should contain "worker role"
      And the output should contain "all servers"

  Scenario: Check configuration parameters - server parameter
    When I run `foreplay check production --server worker.example.com`
    Then the output should contain "Checking"
      And the output should contain "production environment"
      And the output should contain "all roles"
      And the output should contain "worker.example.com server"

  Scenario: Check configuration parameters - short role parameter
    When I run `foreplay check production -r worker`
    Then the output should contain "Checking"
      And the output should contain "production environment"
      And the output should contain "worker role"
      And the output should contain "all servers"

  Scenario: Check configuration parameters - short server parameter
    When I run `foreplay check production -s worker.example.com`
    Then the output should contain "Checking"
      And the output should contain "production environment"
      And the output should contain "all roles"
      And the output should contain "worker.example.com server"
