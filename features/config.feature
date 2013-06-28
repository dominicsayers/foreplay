Feature: Config
  In order to configure Foreplay
  As a CLI
  I want to be as usable as possible

  Scenario: Check configuration
    When I run `foreplay check`
    Then the output should contain "OK"
