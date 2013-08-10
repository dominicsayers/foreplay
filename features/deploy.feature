Feature: Deploy
  In order to use Foreplay
  From the CLI
  I want to be able to access all features

  Scenario: Check configuration
    When I run `foreplay check`
    Then the output should contain "OK"

  Scenario: Check configuration parameters - invalid parameter
    When I run `foreplay check --invalid xyz`
    Then the output should contain:
    	"""
    	ERROR: foreplay check was called with arguments ["--invalid", "xyz"]
		  Usage: "foreplay check".
    	"""

  Scenario: Check configuration parameters - short invalid parameter
    When I run `foreplay check -x xyz`
    Then the output should contain:
      """
		  ERROR: foreplay check was called with arguments ["-x", "xyz"]
		  Usage: "foreplay check".
    	"""

  Scenario: Check configuration parameters - environment parameter
    When I run `foreplay check --environment production`
    Then the output should contain "Checking configuration for"
    And the output should contain "production environment"
    And the output should contain "all roles"
    And the output should contain "all servers"

  Scenario: Check configuration parameters - role parameter
    When I run `foreplay check --role worker`
    Then the output should contain "Checking configuration for"
    And the output should contain "all environments"
    And the output should contain "worker role"
    And the output should contain "all servers"

  Scenario: Check configuration parameters - server parameter
    When I run `foreplay check --server worker.example.com`
    Then the output should contain "Checking configuration for"
    And the output should contain "all environments"
    And the output should contain "all roles"
    And the output should contain "worker.example.com server"

  Scenario: Check configuration parameters - short environment parameter
    When I run `foreplay check -e production`
    Then the output should contain "Checking configuration for"
    And the output should contain "production environment"
    And the output should contain "all roles"
    And the output should contain "all servers"

  Scenario: Check configuration parameters - short role parameter
    When I run `foreplay check -r worker`
    Then the output should contain "Checking configuration for"
    And the output should contain "all environments"
    And the output should contain "worker role"
    And the output should contain "all servers"

  Scenario: Check configuration parameters - short server parameter
    When I run `foreplay check -s worker.example.com`
    Then the output should contain "Checking configuration for"
    And the output should contain "all environments"
    And the output should contain "all roles"
    And the output should contain "worker.example.com server"
