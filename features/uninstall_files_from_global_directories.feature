Feature: uninstall files from global directories I don't have access to
  In order to fully uninstall a gem
  As a user
  I want to uninstall files previously installed in a global directory I have write access to
  
  @wip
  Scenario: The gem contains globally installed files and they don't also belong to any other gem
    Given a gem with some files globally installed in a directory I have write access to
    And that files aren't shared with another gem
    When I run the gem uninstall command
    Then the files should be removed
  