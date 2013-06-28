Feature: Setup
  In order to setup Foreplay
  As a CLI user
  I want to be able to create the config scaffold

  Scenario: Setup
    When I run `foreplay setup`
    Then the following files should exist:
    	| config/foreplay.yml |
