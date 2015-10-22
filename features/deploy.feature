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
# SimpleCov 8+      foreplay deploy requires at least 1 argument: "foreplay deploy ENVIRONMENT".

  Scenario: invalid parameter
    When I run `foreplay deploy test --invalid xyz`
    Then the output should contain:
      """
      ERROR: "foreplay deploy" was called with arguments ["test", "--invalid", "xyz"]
      Usage: "foreplay deploy ENVIRONMENT"
      """
# SimpleCov 8+      foreplay deploy requires at least 1 argument: "foreplay deploy ENVIRONMENT".

  Scenario: short invalid parameter
    When I run `foreplay deploy test -x xyz`
    Then the output should contain:
      """
      ERROR: "foreplay deploy" was called with arguments ["test", "-x", "xyz"]
      Usage: "foreplay deploy ENVIRONMENT"
    	"""
# SimpleCov 8+      foreplay deploy requires at least 1 argument: "foreplay deploy ENVIRONMENT".

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
